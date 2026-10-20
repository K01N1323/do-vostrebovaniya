# Мельниковы — портрет и объёмный чемодан

21 октября 2026. Применён навык imagegen, встроенный инструмент `image_gen`, генерация нового парного портрета по стилевому референсу, `transparent_background=true`. CLI/API и ключ пользователя не использовались.

Игровой ресурс: [melnikovs-v1.png](../assets/characters/melnikovs-v1.png), 1024×1536, RGBA. Файл скопирован в проект без редактирования пикселей, исходная альфа сохранена. Сюжетно это Вера, 37 лет, и Леонид, 39 лет. У каждого свои документы и реплики, у пары один рисованный Sprite3D. Оба персонажа приходят и уходят вместе.

Референс — собственный ранее сгенерированный `fedor-v1.png`, только живописная манера. Исходный результат: `/Users/nikolaj/.codex/generated_images/01a14045-7d37-7ee3-a7be-0272c6e091e9/exec-e3ace43a-5917-4894-86f2-501ef763519e.png`.

Точный запрос:

> Use case: illustration-story. Asset type: paired full-body character sprite for Russian narrative game До востребования. The input image is ONLY an art-style reference, another character Fedor. Generate TWO DISTINCT new people standing close side by side, both facing viewer, full bodies from hair to boots, in a single tall portrait composition, actual transparent alpha background. Vera Melnikova, 37, woman with dark shoulder-length hair tucked behind one ear, narrow thoughtful face, plain muted burgundy sweater beneath worn taupe coat, dark trousers and practical shoes. Leonid Melnikov, 39, man with short brown hair, ordinary mildly tired face, faded navy jacket over light gray shirt, plain trousers and boots. Everyday people separating after years together: restrained awkwardness, no villain coding, no exaggerated misery, both dignified. Vera's hands rest together in front, Leonid's hands near his own jacket pockets, they do not touch. Small visible gap between people. Keep both faces near the center of canvas horizontally, at the same eye height, leave margins around feet and hair; these two must fit in one narrow station service window. Same rough hand-painted gouache/oil treatment, expressive planar brush marks, muted olive, ochre, brown and gray palette, restrained overhead station light as reference. Their faces must look age 37 and 39, not elderly. No luggage, no held props, no scenery, no glow or backdrop, no text, no watermark. Preserve coherent original game art style. Tall 2:3 portrait canvas with both complete figures.

В сцене портрет сдвинут на 0.11 м влево, чтобы стойка не закрывала лицо Леонида. Смещение хранится в `anchor_position` и сохраняется при уменьшении движения.

Чемодан построен кодом `suitcase_view.gd`: корпус, откидная крышка, ручка, три колёсика замка, подкладка, зелёное пятно и один отломанный язычок. Подкладка физически поднимается, после чего становится доступна цель скрытой детали. Битовые изображения чемодана не генерировались и не редактировались.
