# Глеб — портрет и камера в хозяйственной сумке

28 октября 2026. Навык imagegen; встроенный инструмент `image_gen`, новый персонаж по стилевому референсу, `transparent_background=true`.

Игровой ресурс: [gleb-v1.png](../assets/characters/gleb-v1.png), 1024×1536, RGBA. Изображение скопировано без изменения пикселей; исходная альфа сохранена. Стилевой референс — собственный портрет Фёдора, не его личность. Режим CLI/API не применялся.

Источник результата: `/Users/nikolaj/.codex/generated_images/01a1317a-946b-7a62-b12e-68232e1ba6f7/exec-0a27d6aa-8478-44b3-8876-657a633cd70f.png`.

Точный запрос:

> Use case: illustration-story. Asset type: full-body transparent character sprite for the original Russian narrative game До востребования. Input image is ONLY an art-style reference: the game's existing older character Fedor, do not copy his identity or clothes. Generate a DISTINCT new person Gleb Korneev, 29-year-old second-hand electronics reseller. Ordinary young adult man, short slightly unkempt dark blond hair, clean-shaven, narrow alert face, tired but lively eyes, restrained friendly half-smile, looking at the viewer. Everyday worn dark olive lightweight jacket over a gray-brown zip sweater, plain dark trousers, practical sneakers. One thumb hooks casually by his jacket pocket, other hand relaxed, both hands visible. He is socially adept and helpful with repairs but willing to take someone else's property; communicate ambiguity through ordinary believable demeanor, no villain symbols or dramatic smirk. Full figure head to shoes, centered, eye level, spare margin at hair and feet, both shoulders fit a narrow service window. Match the reference's rough hand-painted gouache/oil treatment, expressive planar brushwork, muted olive/ochre/brown/gray palette and subdued station lighting, readable face without photorealism. Actual transparent alpha background. No scenery, no halo/backdrop, no held props, no camera, no text, no watermark. Original human character age 29, not elderly. Tall 2:3 portrait.

Сумка P04 построена средствами Godot в `camera_bag_view.gd`: раскрывающиеся тканевые стороны, ослабленные ручки, серебристый корпус камеры, объектив, ремень со штопкой и ровно три луковицы. Растровые изображения находки не генерировались. Крупные планы используют ту же объёмную модель и реальные цели нажатий.

При просмотре первой версии раскрытая сумка напоминала жёсткий лоток; стороны заменены неровной тканевой поверхностью, добавлены лежащие ручки. Для P04 выделены отдельные места на боковой полке и подставке. При одновременном присвоении P01, P02 и P04 их видимая геометрия не пересекается.

