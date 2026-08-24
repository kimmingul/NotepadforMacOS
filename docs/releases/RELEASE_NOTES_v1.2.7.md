# Notepad for macOS v1.2.7

Closes the remaining holes in how access to your files is remembered. Two of them could lose text.

파일 접근 권한을 기억하는 방식에 남아 있던 구멍을 막았습니다. 그중 둘은 텍스트가 사라질 수 있는 문제였습니다.

**Download:** [Notepad-v1.2.7.pkg](https://github.com/kimmingul/NotepadforMacOS/releases/tag/v1.2.7) — recommended · [Notepad-v1.2.7.dmg](https://github.com/kimmingul/NotepadforMacOS/releases/tag/v1.2.7)
**Site:** https://kimmingul.github.io/NotepadforMacOS/

---

## English

### Fixed
- **Typing into a tab whose file could not be read no longer disarms the overwrite warning.** A tab restored without readable content is marked as such, and saving it asks for confirmation first. Typing a single character used to clear that mark, so the next save silently replaced the original file with a nearly empty document. The mark now survives typing, and what you typed is still kept in the session.

- **A file reached by a different path no longer opens twice.** "Is this file already open?" was answered by comparing path text. macOS APFS is case-insensitive by default, so `Report.txt` and `report.txt` are the same file but compared as two, and a symbolic link and its target compared as two as well. Each duplicate tab had its own copy of the text, and saving one discarded what was typed in the other. Identity now comes from the file system (inode and device), with symbolic links resolved first, and falls back to a normalized path only when the file does not exist.

- **A tab that has no bookmark now gets one the next time you open that file.** A tab holding only a path can still be restored while macOS keeps its own access record for the file, so nothing looked wrong and no bookmark was ever created. Once that record stopped applying, the tab came back empty. Opening the file now stores a read-only bookmark at that moment, which is when access is available.

### Verified
- Restoring a tab saved in an earlier launch and saving it again works without asking for the location: the writable bookmark earned by that first save survives, and an atomic save through it succeeds.
- 119 unit tests, including five that cover the paths above.

### Version
- Marketing version: **1.2.7**
- Build: **12**

---

## 한국어

### 수정
- **원본을 읽지 못한 탭에 입력해도 덮어쓰기 경고가 사라지지 않습니다.** 내용을 읽지 못한 채 복원된 탭은 그렇게 표시되고, 저장할 때 먼저 확인을 받습니다. 이전에는 한 글자만 입력해도 그 표시가 지워져서, 다음 저장이 원본을 거의 빈 문서로 조용히 바꿔버렸습니다. 이제 표시가 유지되며, 입력한 내용도 세션에 그대로 보존됩니다.

- **다른 경로로 같은 파일에 접근해도 두 번 열리지 않습니다.** "이미 열려 있는 파일인가"를 경로 문자열 비교로 판단했습니다. macOS APFS는 기본적으로 대소문자를 구분하지 않아 `Report.txt`와 `report.txt`는 같은 파일인데 둘로 비교됐고, 심볼릭 링크와 대상 파일도 둘로 비교됐습니다. 중복된 탭은 각자 텍스트를 따로 갖고 있어서, 한쪽을 저장하면 다른 쪽에 입력한 내용이 사라졌습니다. 이제 파일 시스템이 주는 식별자(inode·device)로 판단하고, 심볼릭 링크를 먼저 해소하며, 파일이 없을 때만 정규화한 경로로 비교합니다.

- **북마크가 없는 탭은 그 파일을 다음에 열 때 북마크를 받습니다.** 경로만 가진 탭도 macOS가 그 파일에 대한 접근 기록을 유지하는 동안은 복원이 되기 때문에, 겉보기에 문제가 없어 북마크가 만들어지지 않았습니다. 그 기록이 더 이상 적용되지 않는 순간 그 탭은 빈 상태로 복원됐습니다. 이제 파일을 열 때, 즉 접근 권한이 있는 그 시점에 읽기 전용 북마크를 저장합니다.

### 검증
- 이전 실행에서 저장한 탭을 복원해 다시 저장하면 위치를 묻지 않고 성공합니다. 첫 저장으로 얻은 쓰기 가능 북마크가 유지되고, 그것으로 원자적 저장이 됩니다.
- 단위 테스트 119개 통과(위 경로를 다루는 5개 포함).

### 버전
- 표시 버전: **1.2.7**
- 빌드: **12**

---

**Developer:** Min-Gul Kim, MD, PhD — Jeonbuk National University Medical School
License: MIT · © 2026 Min-Gul Kim
