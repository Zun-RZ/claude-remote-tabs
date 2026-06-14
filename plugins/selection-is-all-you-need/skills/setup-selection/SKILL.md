---
name: setup-selection
description: Use to reduce the one-time mobile permission prompt for AskUserQuestion and check push-notification settings. Run once, ideally from desktop.
---

# setup-selection

`selection-is-all-you-need` 플러그인이 매 턴 끝 AskUserQuestion을 호출하면,
모바일에서 세션당 1회 "AskUserQuestion 권한을 주시겠습니까?" 팝업이 뜰 수
있다. 동작을 막지는 않지만 거슬린다. 이 스킬은 그것을 줄이려 시도한다.

## 동작 (best-effort)

1. 사용자 `~/.claude/settings.json`(없으면 생성)을 읽어
   `permissions.allow` 배열에 `"AskUserQuestion"` 항목이 없으면 추가한다.
   기존 값은 보존하고 멱등하게 동작한다.
2. 푸시 알림 설정을 점검해 안내한다: `agentPushNotifEnabled`(true 권장),
   `preferredNotifChannel`.

## 한계 (반드시 사용자에게 고지)

AskUserQuestion 은 공식적으로 권한 대상이 아니다(Claude Code Tools
reference: `Permission Required: No`). 따라서 위 allow 항목이 팝업을 없애지
못할 수 있다. 그 경우 "세션당 1회 확인은 모바일 앱의 플랫폼 동작이며
플러그인으로 제거할 수 없다"고 사용자에게 명확히 알리고 종료한다.
