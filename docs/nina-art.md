# Нина — проба художественного направления, итерация 0.2

Дата: 15 октября 2026 года.

Это оригинальный игровой образ для проверки направления графики и читаемости посетителя за стойкой. Он не означает завершение финальных моделей, анимаций и всего художественного оформления.

## Выбранный ассет

- Игровой путь: `res://assets/characters/nina-v1.png`.
- Файл в проекте: `assets/characters/nina-v1.png`.
- Исходный выбранный output: `/Users/nikolaj/.codex/generated_images/01a1407c-5c37-7731-a384-a039045dcde2/exec-40ca9a5e-849f-4a1f-aa78-406461bc8f39.png`.
- Режим: default built-in `image_gen.imagegen`, сначала generate, затем один edit с `referenced_image_paths` и `transparent_background: true`. CLI/API fallback не использовался.
- Размер: 1024 × 1536 пикселей, PNG RGBA.
- Альфа из imagegen сохранена в исходном виде. Обработки пикселей, ресайза, вырезания фона или перекрашивания кодом нет; выбранный output скопирован в проект.
- Проверены полный силуэт, лицо, руки, обувь, отсутствие предметов/текста и альфа. В образцах фона снаружи фигуры alpha=0; в силуэте alpha до 254. На отдельных краях возможны почти невидимые alpha=1. При необходимости renderer может применить alpha-scissor 0.05, не меняя PNG.

Повторная проверка видимого в некоторых просмотрщиках коричневого ореола: это RGB-цвет под прозрачностью, а не непрозрачный фон. В точке (150,700) RGBA=(17,12,9,0), в (850,700) RGBA=(51,36,24,0). В полосе x=0…249 максимум alpha=1, в полосе x=780…1023 максимум alpha=2. Порог alpha-scissor 0.05 соответствует alpha≥13 из 255; он отбрасывает все эти фоновые пиксели. Bbox оставшегося изображения при этом (255,27)–(777,1509), совпадает с фигурой. Прямоугольник фона за Ниной не возникает. Все проверки были только чтением; пиксели не редактировались.

Нина: обычная женщина 57 лет, короткие седеющие волосы, усталое живое лицо, потёртый рабочий жилет оливкового оттенка, коричневая одежда и свободные пустые руки. Второй проход добавил грубые плоскости и фактурность. Референсы использованы как общее направление, без заимствования конкретного персонажа.

## Геометрия для Sprite3D

Координаты изображения считаются от левого верхнего угла. Области лица ниже приблизительны и указаны для размещения за решёткой/наведения, а не как результат автоматического распознавания.

| Параметр | Значение |
|---|---|
| Полотно | 1024 × 1536 |
| Силуэт alpha > 20, bbox в пикселях | x=255…777, y=28…1509 |
| Нормализованный bbox силуэта | [0.2490, 0.0182, 0.7588, 0.9824] |
| Приблизительный bbox лица | [0.424, 0.057, 0.578, 0.179] |
| Приблизительный центр лица | (0.498, 0.116) |
| Приблизительная линия глаз | y=0.096 |
| Высота плоскости Sprite3D | 1.72 м |
| pixel_size | 1.72 / 1536 = 0.00111979167 |
| Рекомендуемый центр плоскости над полом | y=0.86 м |
| Фактическая верхушка силуэта при этих параметрах | ~1.689 м |
| Фактическая подошва при этих параметрах | ~0.030 м |
| Приблизительная высота глаз при этих параметрах | ~1.555 м |

При размещении важно оставлять лицо видимым в проёме решётки и не располагать поверх него толстую перекладину. Фигура рассчитана на фронтальный вид; это плоский 2.5D ассет, а не поворачиваемая полноценная модель.

## Точный prompt первого generate

```text
Use case: stylized-concept
Asset type: original full-body transparent PNG NPC sprite for a first-person 2.5D narrative game, seen across a protected service counter.
Primary request: one original ordinary 57-year-old Russian woman named Nina, a cleaner at an old provincial Russian bus terminal. Face directly toward the camera and look at the player. Real adult body proportions, quiet worn dignity and a tired, living, human face, recognizably individual. Short greying hair, plain weathered face, under-eye fatigue, small expressive eyes, a slightly guarded neutral mouth. She wears a faded olive work vest over a worn brown long-sleeve top, plain dark trousers and practical worn shoes. Her empty hands hang relaxed naturally near the front sides of her hips, clearly separate from clothing; modest asymmetry, weight settled on one leg.
Style/medium: gritty handmade retro game character, realistic photomontage and rough painted treatment, strongly readable planes of shadow, scuffed fabric and muted dirty textures, as an original asset in the broad visual direction of Arctic Eggs and No I'm not a Human. A deliberate slightly uncanny low-resolution indie texture character with convincing anatomy and human warmth, not a polished glossy 3D model and not a standard stock photograph.
Composition/framing: one woman only, complete entire silhouette from hair to soles visible, straight-on full body, vertically oriented composition, centered, modest clean transparent margins around every edge. Camera around chest height, no dramatic perspective. Arms stay close enough for a counter window composition. The face must remain clearly readable at game scale.
Lighting/mood: soft cool frontal light with a faint warm side edge on one side, sombre late evening, restrained contrast.
Scene/backdrop: actual transparent alpha background, no environment, no scenery, no floor, no cast shadow on any background.
Constraints: empty hands, no items, no props, no counter or grille, no lettering, no logos, no watermarks. No cropping of head, hands or shoes. Do not copy any existing game character. Avoid horror monster, grotesque anatomy, blood, violence, cartoon doll, cute chibi, anime, glamour, plastic skin, fashionable new clothes, shiny rendered 3D.
```

Первый output: `/Users/nikolaj/.codex/generated_images/01a1407c-5c37-7731-a384-a039045dcde2/exec-8e318da3-55fb-4c2d-9041-940093f24b9e.png`.

## Точный финальный prompt (edit)

Вход edit — первый output выше. Параметры: `referenced_image_paths: [первый output]`, `transparent_background: true`.

```text
Use case: style-transfer
Asset type: transparent full-body game NPC sprite.
Edit target: the provided original full-body woman. Preserve her exact identity, age, tired ordinary living face, hairstyle, clothes, complete full-body pose, empty relaxed hands, framing and body proportions.
Primary request: change only the rendering treatment from smooth studio photography to gritty 1998-era photomontage texture art for an original sombre first-person indie game. Introduce deliberately broad angular shadow shapes, limited rough muddy colour tones, coarse hand-painted surface texture and slightly posterized visual planes on the face and clothing, while keeping the person believable, expressive and natural. The eyes and facial features must remain clearly recognizable. Use a restrained handmade retro treatment, similar in broad direction to Arctic Eggs / No I'm not a Human, without copying a character or design. No cartoon linework, no chibi or plastic 3D effect.
Background extraction: remove every trace of the background including the entire coloured haze or glow around the figure. Actual fully transparent alpha everywhere outside her silhouette. Keep the clean antialiased outline. No floor, no shadow floating behind her.
Lighting: retain cool readable front lighting with just a tiny warm side accent on the person.
Invariants: one woman, entire head hands and shoes inside frame, keep exact subject and pose, no text, no logos, no objects, no extra people, no violence, no monsters.
```
