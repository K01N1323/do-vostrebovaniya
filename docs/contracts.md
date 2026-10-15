# Контракт прототипа — итерация 1

Единственный Autoload: `GameStore`. Весь изменяемый игровой прогресс хранится в нём; сцены получают глубокие копии.

`GameStore.dispatch(command: Dictionary) -> Dictionary` возвращает `{ok: bool, error: String}`. Команда `{type: String, ...поля}`. После успешной команды сигнал `state_changed(snapshot: Dictionary)`, после отказа `command_rejected(reason: String)`.

`GameStore.get_snapshot() -> Dictionary`:
```
{
  version: 1, started: false, case_id: "nina", case_status: "active" | "resolved",
  package: {id: "P01", location: "shelf" | "desk" | "issued" | "personal", opened: false},
  read_documents: [], inspected_details: [], asked_topics: [],
  dialogue_id: "greeting", decision: "" | "issue" | "retain" | "appropriate"
}
```

Команды: `START`, `MOVE_PACKAGE {destination: "desk"|"shelf"}`, `OPEN_PACKAGE`, `INSPECT_DETAIL {detail_id: "sandwiches"|"saucer"|"napkin"}`, `READ_DOCUMENT {document_id: "identity"|"claim"}`, `ASK_TOPIC {topic_id: "carrier"|"old_room"|"lunch"}`, `ISSUE_PACKAGE {recipient: "nina"}`, `RETAIN_PACKAGE`, `APPROPRIATE_PACKAGE`, `RESTART`.

Открытие и осмотр доступны на столе. Вопрос lunch — после осмотра sandwiches. Решение допустимо при прочтённых двух бумагах, открытом пакете и хотя бы одном осмотренном признаке. Выдача и присвоение — со стола. Оставление на хранении допустимо со стола/полки. MOVE_PACKAGE не завершает обращение. После решения все игровые команды, кроме RESTART, отклоняются. UI не показывает моральных оценок.

`package.opened` фиксирует, что доступ к содержимому уже был открыт. В представлении крышка и дверца закрыты на полке и в личном месте, чтобы переноска помещалась под столом/полкой. На столе и в сцене осмотра доступ к уже открытому содержимому восстанавливается. Наблюдения сохраняются независимо от визуального положения крышки.

`GameStore.content`: Dictionary из `data/nina.json` с полями `documents` (id -> {title, text}), `details` (id -> {title, text}), `dialogues` (id -> String), `reactions` (decision -> String). Контент не содержит исполняемых выражений.

## Представление

`scenes/room/room.tscn` (Node3D, `room_view.gd`) содержит место, Нину и пакет. Методы `apply_snapshot(snapshot)`, `set_hovered(target_id)`; сигнал `target_clicked(target_id: String)` (P01, identity, claim, nina, archive). Позиции P01: shelf=(-2.3,1.2,-1.8), desk=(0,0.98,-0.35), personal=(1.15,0.3,0.55), issued — скрыт. Допустимо изменить координаты согласованно с камерой.

`scenes/room/camera_rig.tscn`, скрипт `camera_rig.gd`: Camera3D доступна через `get_camera()`, `focus(view_id: String)` для window/shelf/desk/personal, `reduced_motion: bool`. Сигнал `view_changed(view_id: String)`. Стартовый вид — window. Камера в рабочей комнате без свободного хождения.

`scenes/objects/package.tscn` — самостоятельная переноска, на root методы `set_opened(value: bool)`, `set_highlighted(value: bool)`. `scenes/objects/inspection_stage.tscn` — отдельный объект для крупного осмотра, метод `rotate_item(direction: float)`.

Главную сцену, GameStore, правила, UI, загрузку, project.godot и интеграцию меняет только оркестратор. Представление и тесты редактируют назначенные агенты в собственных файлах.
