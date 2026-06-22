#!/usr/bin/env python
# remote-tabs — Windows ConPTY 키주입 호스트.
# claude를 ConPTY로 spawn해 PTY를 소유하고, inbox 파일의 새 줄을 그 PTY stdin에
# 키로 주입한다. 이로써 모델·훅으로는 불가능한 /clear 등 내장명령까지 진짜 발동한다.
# (Start-Process 미니마이즈드 런처는 PTY를 안 쥐어 주입 불가 → 이 호스트가 대체.)
# tui-keystroke-bridge(Zun-RZ) 의 windows/pty_host.py 를 벤더링.
#
# 사용: python pty_host.py <inbox-file> [--] [command...]
#   기본 command = claude. spawn되는 자식엔 CLAUDE_BRIDGE_INBOX 환경변수가 설정돼
#   세션 안의 모델이 `echo /clear >> "$CLAUDE_BRIDGE_INBOX"` 로 자기 inbox를 찾을 수 있다.
import os
import sys
import threading
import time

from winpty import PtyProcess

POLL_INTERVAL = 1.0  # Windows엔 inotify가 없어 단순 폴링
ESC_SETTLE = 0.4     # 슬래시/배시 명령 주입 전 ESC를 보내고 모달이 닫힐 시간을 준다

# stdout이 파이프/파일로 리다이렉트되면 cp1252가 돼 claude의 UTF-8 출력에서
# UnicodeEncodeError로 펌프 스레드가 죽는다 → UTF-8 강제(+안전망 replace).
for _s in (sys.stdout, sys.stderr):
    try:
        _s.reconfigure(encoding="utf-8", errors="replace")
    except (AttributeError, ValueError):
        pass


def completed_lines(inbox):
    """개행으로 끝난 '완결된' 줄만 반환 (= 주입 대상). wc -l 의미와 동일."""
    try:
        with open(inbox, "r", encoding="utf-8") as f:
            text = f.read()
    except FileNotFoundError:
        return []
    return text.split("\n")[:-1]


def read_offset(state):
    try:
        with open(state, "r", encoding="utf-8") as f:
            return int(f.read().strip() or 0)
    except (FileNotFoundError, ValueError):
        return 0


def write_offset(state, n):
    with open(state, "w", encoding="utf-8") as f:
        f.write(str(n))


def inject_new(proc, inbox, state):
    """inbox에서 아직 안 본 완결된 줄을 PTY stdin에 주입."""
    lines = completed_lines(inbox)
    seen = read_offset(state)
    if len(lines) <= seen:
        return
    for line in lines[seen:]:
        # /명령(/clear)·!배시는 명령 프롬프트의 기능이라 거기서만 동작한다(평문과 다름).
        # 턴 끝의 AskUserQuestion·권한·폴더신뢰 모달이 떠 있으면 주입이 거기 갇히므로
        # ESC로 모달을 닫고 명령 프롬프트로 복귀시킨 뒤 주입한다.
        if line.startswith(("/", "!")):
            proc.write("\x1b")
            time.sleep(ESC_SETTLE)
        proc.write(line + "\r")  # PTY는 줄 끝 CR
    write_offset(state, len(lines))


def pump_output(proc):
    """PTY 출력을 stdout으로 흘려보낸다 (백그라운드면 로그/버림으로 리다이렉트)."""
    while True:
        try:
            data = proc.read(4096)
        except EOFError:
            break
        if data:
            sys.stdout.write(data)
            sys.stdout.flush()


def forward_console_input(proc):
    """이 콘솔 창에 '포커스가 있을 때 친' 키만 PTY로 전달한다.
    콘솔 입력 버퍼는 그 창이 키보드 포커스를 가질 때만 채워지므로, 창이 비활성이면
    읽기가 블록될 뿐 전역 입력을 가로채지 않는다 (SendInput/전역 키보드 훅 미사용 —
    엉뚱한 창에 입력될 위험 없음). 콘솔이 아니면(백그라운드/리다이렉트) 아무것도 안 한다.

    콘솔을 raw + VT 입력 모드로 둔다:
    - ENABLE_PROCESSED_INPUT 끔 → Ctrl-C가 신호로 호스트를 죽이지 않고 \x03 바이트로 와
      그대로 claude에 전달된다(=claude 작업만 인터럽트). ESC도 \x1b로 그대로 전달.
    - ENABLE_VIRTUAL_TERMINAL_INPUT 켬 → 화살표/Home/End 등이 VT 시퀀스로 들어와 전달.
    - LINE/ECHO 끔 → 줄 단위·에코 없이 키 단위로(에코는 claude가 한다)."""
    if os.name != "nt":
        return
    import ctypes
    try:
        import msvcrt
        handle = msvcrt.get_osfhandle(sys.stdin.fileno())
    except Exception:
        return
    k32 = ctypes.windll.kernel32
    old = ctypes.c_uint()
    if not k32.GetConsoleMode(handle, ctypes.byref(old)):
        return  # 콘솔이 아님 (파이프/리다이렉트) → no-op
    ENABLE_PROCESSED_INPUT = 0x0001
    ENABLE_LINE_INPUT = 0x0002
    ENABLE_ECHO_INPUT = 0x0004
    ENABLE_VIRTUAL_TERMINAL_INPUT = 0x0200
    new = (old.value & ~(ENABLE_PROCESSED_INPUT | ENABLE_LINE_INPUT | ENABLE_ECHO_INPUT)) \
        | ENABLE_VIRTUAL_TERMINAL_INPUT
    k32.SetConsoleMode(handle, new)
    fd = sys.stdin.fileno()
    try:
        while proc.isalive():
            data = os.read(fd, 64)  # 포커스된 콘솔의 키 바이트(VT 시퀀스 포함). 비활성이면 블록.
            if not data:
                break
            proc.write(data.decode("utf-8", "replace"))
    except Exception:
        pass
    finally:
        k32.SetConsoleMode(handle, old.value)


def main(argv):
    if len(argv) < 2:
        print("usage: python pty_host.py <inbox-file> [--] [command...]", file=sys.stderr)
        return 2
    inbox = os.path.expanduser(argv[1])
    rest = argv[2:]
    if rest and rest[0] == "--":
        rest = rest[1:]
    command = rest or ["claude"]
    state = inbox + ".offset"

    # 시작 시점의 기존 inbox 내용은 처리된 것으로 간주 (재시작 시 과거 줄 재주입 방지).
    open(inbox, "a", encoding="utf-8").close()
    write_offset(state, len(completed_lines(inbox)))

    # 세션 안의 모델이 자기 inbox를 찾을 수 있도록 환경변수로 전달.
    env = dict(os.environ)
    env["CLAUDE_BRIDGE_INBOX"] = inbox

    proc = PtyProcess.spawn(command, env=env)
    print(f"[pty_host] spawned {command!r}  inbox={inbox}", file=sys.stderr)

    reader = threading.Thread(target=pump_output, args=(proc,), daemon=True)
    reader.start()
    # 로컬 창에 포커스가 있을 때 친 키도 PTY로 전달 (inbox 주입과 공존). 콘솔이 아니면 no-op.
    threading.Thread(target=forward_console_input, args=(proc,), daemon=True).start()

    try:
        while proc.isalive():
            inject_new(proc, inbox, state)
            time.sleep(POLL_INTERVAL)
    except KeyboardInterrupt:
        pass
    finally:
        proc.close(force=True)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
