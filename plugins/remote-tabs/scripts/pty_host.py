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

from winpty import Backend, PtyProcess

POLL_INTERVAL = 1.0  # Windows엔 inotify가 없어 단순 폴링
ESC_SETTLE = 0.4     # 슬래시/배시 명령 주입 전 ESC를 보내고 모달이 닫힐 시간을 준다
PASTE_SETTLE = 0.1   # bracketed paste 종료 후 제출 CR을 보내기 전 짧은 대기

# PTY로의 write는 원래 두 곳(inbox 주입 / 로컬 콘솔 입력 전달)에서 서로 다른 스레드가
# 한다. 이 락으로 직렬화해, 주입 명령의 ESC+명령 2단계 사이에 로컬 키가 끼어드는 오염을
# 막는다. (로컬 입력 포워딩은 현재 비활성이라 지금은 inject_new 단독 writer지만, 부활
# 대비 락을 유지한다 — main()의 비활성 블록 참조.)
_write_lock = threading.Lock()

# 런처는 pty_host를 stdout/stderr=DEVNULL로 띄운다(과거 pythonw 경로에선 콘솔이 없어
# sys.stdout이 None일 수도 있었다). 어느 쪽이든 write·진단 print가 None/닫힘에서 죽지
# 않게 방어적으로 devnull로 재오픈한다.
if sys.stdout is None or sys.stderr is None:
    _devnull = open(os.devnull, "w")
    if sys.stdout is None:
        sys.stdout = _devnull
    if sys.stderr is None:
        sys.stderr = _devnull

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
        # ESC+명령을 한 락 구간으로 묶어 로컬 콘솔 입력과 인터리브되지 않게 한다.
        with _write_lock:
            if line.startswith(("/", "!")):
                proc.write("\x1b")
                time.sleep(ESC_SETTLE)
            if line.startswith("!"):
                # !ls를 생바이트로 쏘면 bash 모드(!) 진입이 안 잡힌다(실제 붙여넣기는 됨).
                # 붙여넣기처럼 bracketed paste로 본문만 감싸고, 제출 CR은 페이스트 종료
                # (\x1b[201~) 뒤에 따로 보낸다(브래킷 안의 CR은 개행으로 삽입돼 버린다).
                proc.write("\x1b[200~" + line + "\x1b[201~")
                time.sleep(PASTE_SETTLE)
                proc.write("\r")
            else:
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


def enable_console_raw():
    """stdin이 콘솔이면 raw + VT 입력 모드로 전환하고 (kernel32, handle, old_mode)를
    반환한다. 콘솔이 아니거나 Windows가 아니면 None. (모드 복원은 호출부 finally에서.)
    - ENABLE_PROCESSED_INPUT 끔 → Ctrl-C가 신호로 호스트를 죽이지 않고 \x03로 와 claude에 전달.
    - ENABLE_VIRTUAL_TERMINAL_INPUT 켬 → 화살표/Home/End 등이 VT 시퀀스로 들어온다.
    - LINE/ECHO 끔 → 키 단위로(에코는 claude가 한다)."""
    if os.name != "nt":
        return None
    import ctypes
    try:
        import msvcrt
        handle = msvcrt.get_osfhandle(sys.stdin.fileno())
    except Exception:
        return None
    k32 = ctypes.windll.kernel32
    # 64비트 HANDLE이 c_int로 절단되지 않게 인자 타입을 명시.
    k32.GetConsoleMode.argtypes = [ctypes.c_void_p, ctypes.POINTER(ctypes.c_uint)]
    k32.SetConsoleMode.argtypes = [ctypes.c_void_p, ctypes.c_uint]
    old = ctypes.c_uint()
    if not k32.GetConsoleMode(handle, ctypes.byref(old)):
        return None  # 콘솔이 아님 (파이프/리다이렉트)
    ENABLE_PROCESSED_INPUT = 0x0001
    ENABLE_LINE_INPUT = 0x0002
    ENABLE_ECHO_INPUT = 0x0004
    ENABLE_VIRTUAL_TERMINAL_INPUT = 0x0200
    new = (old.value & ~(ENABLE_PROCESSED_INPUT | ENABLE_LINE_INPUT | ENABLE_ECHO_INPUT)) \
        | ENABLE_VIRTUAL_TERMINAL_INPUT
    k32.SetConsoleMode(handle, new)
    return (k32, handle, old.value)


def restore_console(console):
    if not console:
        return
    k32, handle, old = console
    try:
        k32.SetConsoleMode(handle, old)
    except Exception:
        pass


def forward_console_input(proc):
    """이 콘솔 창에 '포커스가 있을 때 친' 키만 PTY로 전달한다.
    콘솔 입력 버퍼는 그 창이 키보드 포커스를 가질 때만 채워지므로, 창이 비활성이면
    읽기가 블록될 뿐 전역 입력을 가로채지 않는다 (SendInput/전역 키보드 훅 미사용 —
    엉뚱한 창에 입력될 위험 없음). 콘솔은 호출 전 enable_console_raw로 raw+VT 상태.
    sys.stdin.buffer(=_WindowsConsoleIO, ReadConsoleW)로 읽어 UTF-8을 올바르게 받는다
    (os.read는 OEM 코드페이지라 비ASCII가 깨짐)."""
    try:
        reader = sys.stdin.buffer
    except Exception:
        return
    try:
        while proc.isalive():
            data = reader.read1(64)  # 포커스된 콘솔의 키(VT 포함). 비활성이면 블록.
            if not data:
                break
            with _write_lock:
                proc.write(data.decode("utf-8", "replace"))
    except Exception as e:
        print(f"[pty_host] local input forwarding stopped: {e}", file=sys.stderr)


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

    # ConPTY 백엔드를 명시한다. backend=None(기본)이면 네이티브가 auto-select하는데,
    # 레거시 WinPTY 백엔드로 떨어지면 winpty-agent.exe가 자기 콘솔을 새로 만든다 —
    # 부모가 창 없는 콘솔(런처의 CREATE_NO_WINDOW)일 때 그 agent 콘솔이 세션을 처음
    # 켜는 순간 검은 창으로 잠깐 뜬다. ConPTY는 CreatePseudoConsole 기반이라 진짜
    # 헤드리스 — 창이 없다. (Win10 1809+/Win11에서 항상 가용; 이 호스트는 Windows 전용.)
    proc = PtyProcess.spawn(command, env=env, backend=Backend.ConPTY)
    print(f"[pty_host] spawned {command!r}  inbox={inbox}", file=sys.stderr)

    threading.Thread(target=pump_output, args=(proc,), daemon=True).start()

    # ── 로컬 콘솔 입력 포워딩 (REMOTE_TABS_WINDOW로 토글) ─────────────────────────
    # 포커스된 로컬 창에 친 키를 PTY로 전달한다. 런처가 pty_host를 어떻게 띄웠는지로
    # self-gate한다: 기본(무창)은 stdin=DEVNULL이라 enable_console_raw가 None을 반환해
    # 자동 no-op이고, REMOTE_TABS_WINDOW=1이면 런처가 최소화된 '보이는' 콘솔로 띄워
    # stdin이 진짜 콘솔이 되어 포워딩이 활성화된다(한글 등 로컬 타이핑). 이 분기는
    # 콘솔 유무 한 곳만 보면 되도록 pty_host에서 환경변수를 직접 읽지 않는다.
    console = enable_console_raw()
    if console:
        threading.Thread(target=forward_console_input, args=(proc,), daemon=True).start()

    try:
        while proc.isalive():
            inject_new(proc, inbox, state)
            time.sleep(POLL_INTERVAL)
    except KeyboardInterrupt:
        pass
    finally:
        restore_console(console)  # console=None이면 no-op; 부활 시 모드 복원
        proc.close(force=True)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
