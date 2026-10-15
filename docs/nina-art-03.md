# Нина v2 — художественная итерация 0.3

Дата: 15 октября 2026 года.

Задача — довести художественный язык одной сцены до выразительного образца перед расширением сюжета. Для нового образа выбран явно нарисованный, намеренно неровный и слегка тревожный язык. Он заменяет фотографический характер v1 в текущей сцене; старый PNG сохранён.

## Референс и художественное решение

Изучены [официальная Steam-страница No, I'm not a Human](https://store.steampowered.com/app/3180070/No_Im_not_a_Human/) и [официальный скриншот](https://shared.fastly.steamstatic.com/store_item_assets/steam/apps/3640000/9fa5666773b0cb493f120834e0659c30592e6a9d/ss_9fa5666773b0cb493f120834e0659c30592e6a9d.jpg). Скриншот передан imagegen только как образец художественной обработки. Его персонаж, помещение, поза, интерфейс и зелёный эффект ночного видения в новый ассет не переносились.

Авторская интерпретация применённых приёмов: крупные асимметричные глаза, вытянутые неровные черты, увеличенная голова, очень тёмные широкие пятна тени, ограниченные световые градации, грубые кистевые мазки. Палитра Нины — грязный шалфей, выцветшая охра и бурые тени. Костюм сохраняет рабочий жилет, коричневый верх и простую практичную одежду. Нина остаётся человеком с усталым и настороженным выражением, без насилия и монструозных деталей.

Это полный игровой ассет для художественной проверки сцены 0.3. Одна иллюстрация не означает завершение всех персонажей, анимаций и художественной части игры.

## Выбранный файл и происхождение

- Игровой путь: `res://assets/characters/nina-v2.png`.
- Файл проекта: `assets/characters/nina-v2.png`.
- Исходный output: `/Users/nikolaj/.codex/generated_images/01a1407c-5c37-7731-a384-a039045dcde2/exec-5e98d179-3978-4f2f-b5df-f1a96680c385.png`.
- Режим: default built-in `image_gen.imagegen`; один новый generate со style-only reference, `transparent_background: true`.
- Референс imagegen: `/tmp/nina-reference-steam.jpg` — официальный скриншот из ссылки выше.
- Исходный v1 не использован как edit target: это позволило заново нарисовать лицо и избежать инерции фотографического стиля.
- Результат просмотрен целиком. Дополнительный edit не потребовался.
- CLI/API fallback, ручная/программная перерисовка, ресайз и удаление фона не применялись. PNG скопирован из output без изменения пикселей.
- Отдельный кадр моргания не создан; первый приоритет — целостное лицо и качественная интеграция одного образа.

## Альфа и проверка

Формат PNG RGBA, 1024 × 1536 пикселей, диапазон alpha 0…254.

| Проверка | Результат |
|---|---|
| RGBA в точке (150,700) | (1,0,1,0) |
| RGBA в точке (850,700) | (5,4,1,0) |
| RGBA в точке (0,0) | (1,1,1,0) |
| RGBA в точке (512,0) | (54,50,34,0) |
| Максимум alpha в полосе x=0…249 | 1 |
| Максимум alpha в полосе x=780…1023 | 1 |
| Bbox при alpha≥13, то есть пороге 0.05 | (265,12)–(765,1524) |
| Bbox при alpha>20 | (265,12)–(764,1524) |

Отображаемое некоторыми просмотрщиками слабое грязноватое свечение относится к RGB под alpha=0. При alpha-scissor 0.05 оно полностью отбрасывается; остаётся силуэт, а не прямоугольник. Альфа сохранена как сгенерирована.

## Геометрия Sprite3D

Координаты нормализуются от левого верхнего угла изображения. Лицо и линия глаз оценены по визуальному просмотру, без автоматического распознавания.

| Параметр | Финальная интеграция 0.3 |
|---|---|
| Полотно | 1024 × 1536 |
| Bbox силуэта alpha≥13 в нормализованных координатах | [0.2588, 0.0078, 0.7471, 0.9922] |
| Приблизительный bbox лица | [0.406, 0.056, 0.596, 0.203] |
| Приблизительный центр лица | (0.501, 0.130) |
| Приблизительная линия глаз | y=0.110 |
| Высота плоскости Sprite3D | 1.84 м |
| pixel_size | 1.84 / 1536 = 0.00119791667 |
| Центр плоскости над полом | y=0.92 м |
| Фактическая верхушка силуэта | ~1.826 м |
| Фактическая подошва | ~0.014 м |
| Центр лица над полом | ~1.601 м |
| Линия глаз над полом | ~1.638 м |

Положение ожидания (0, 0, −0.94), Sprite3D смещён на +0.06 по z; FOV вида окна 42°. Добавлены слабое дыхание и покачивание при ходьбе, отключаемые настройкой уменьшения движения. Крупный план проверен графическим прогоном: лицо и глаза должны попадать в центральный проём. Основная узнаваемость здесь заложена в рисунке, а не в сильном сценическом шуме поверх него. Это фронтальный плоский 2.5D ассет.

## Точный prompt

Параметры вызова: `referenced_image_paths: ["/tmp/nina-reference-steam.jpg"]`, `transparent_background: true`.

```text
Use case: stylized-concept
Asset type: original transparent full-body front-facing NPC sprite for a grim first-person 2.5D narrative game.
Input images: the provided game screenshot is a STYLE REFERENCE ONLY. Study its deliberate distorted painted anatomy, enormous expressive eyes, rough ink-like shadow masses and limited posterized colour values. Do not reproduce its man, pose, outfit, teal night vision, room, composition, interface or writing.
Primary request: design an original 57-year-old female cleaner from an old Russian provincial bus terminal. Her name is Nina. An ordinary tired working woman with a guarded, gentle, very human expression. She looks directly at the player. The most important element is a compelling painted face: asymmetrical elongated narrow cheeks, slightly too-large deep-set expressive eyes with visible small warm brown irises, heavy eyelids and dark eye sockets, long crooked nose, a narrow lopsided closed mouth, short sparse rough greying hair, weathered uneven face. Her head is deliberately larger than anatomically realistic, about one fifth of her full height, without becoming cute. One shoulder is subtly higher, the neck forward, slight tired hunch, natural adult slim body. Empty hands rest loosely at lower belly/hips with readable long knuckles; no grasped item.
Clothing: shabby olive sage sleeveless utility vest with large old pockets, muted brown long-sleeved top underneath, brown-black straight worn trousers and simple closed work shoes. Loose dull cloth, practical unglamorous clothing.
Style/medium: a forcefully PAINTED ORIGINAL GAME CHARACTER with the visual language of No, I'm not a Human: deliberately uncanny distorted photomontage that has been completely overpainted in rough opaque gouache and scratched charcoal. Long asymmetrical planes, bold almost-black irregular contour and deep blocky shadows, coarse brush scumbles, dark crosshatching only in a few areas, severely posterized 4–5 values. Eyes and mouth are expressive hand-drawn shapes. Broken brush edges and organic dirty texture. Graphic pigment on paper, never photographic skin detail. It must visibly read as an authored strange painting from across a room, not a photo with a texture filter, not a faceted polygon filter, not a smooth digital portrait. Restrained oddness of an exhausted human, no monster.
Palette: only dirty pale ochre and faded sage highlights, desaturated clay brown midtones, extremely dark brown-green shadows. No bright colours. More expressive eyes than realism, coherent rough painting across the whole body.
Composition/framing: single woman only, directly front facing, whole full body from hair to shoe soles inside image with transparent margin, vertical centered composition. The large face must remain the visual focus, shoulders and hands readable. Simple frontal game sprite view, no dramatic perspective.
Lighting: broad dull cool front light, a subtle ochre side light only on her face/vest, three strong value groups, no photographic studio rimlight or bloom.
Scene/backdrop: true alpha transparency, isolated woman only. No floor, no environment, no haze or glow behind the silhouette, no cast shadow on a backdrop.
Constraints: original person, do not copy a game character. Complete silhouette, clear alpha edges. No letters, text, logos, watermarks, grilles, counter, props or other people. No violence, gore or body horror. Avoid photograph, photorealism, realistic pores, stock-photo woman, glossy 3D render, cute illustration, anime, comic cartoon, chibi, low-poly facets, giant grin, teeth showing.
```

