# Художественные материалы 0.3

Пользователь выбрал доводку одной сцены до расширения сюжета. Изучены [официальная страница игры](https://store.steampowered.com/app/3180070/No_Im_not_a_Human/) и [официальный кадр демо](https://shared.fastly.steamstatic.com/store_item_assets/steam/apps/3640000/9fa5666773b0cb493f120834e0659c30592e6a9d/ss_9fa5666773b0cb493f120834e0659c30592e6a9d.jpg). Наблюдения по изображениям: широкие тени, локальный холодный свет, рисованная деформация лица и фактурные бытовые поверхности. Это визуальный анализ, а не утверждение о внутреннем рендерере чужой игры. Поиск Spotlight по human/arctic/человек на Mac подходящих файлов не вернул.

Все три изображения созданы встроенным imagegen в режиме generate, без изображений чужих игровых материалов на входе, без CLI/API fallback. PNG скопированы в проект без пиксельного редактирования. Реальные текстуры заменяют прежний 64×64 шум. Собственный triplanar-шейдер проецирует материалы в локальных координатах, сохраняет масштаб в метрах и следует за движущимися объектами. У штукатурки уменьшена контрастность фактуры до 0.42, дерева до 0.60, металла до 0.48; крупные пятна не конкурируют с лицом. Пластик переноски использует отдельную мелкую процедурную фактуру. Бумага, ткань, кафель и кожа дополнены непрерывной мелкой процедурной фактурой.

Обработка комнаты вынесена в FilmGrade перед интерфейсом: ограничение пространственной резкости, умеренная постеризация, холодные тени, плёночное зерно и виньетка. Документы и текст рисуются после обработки. Новый персонаж описан в [nina-art-03.md](nina-art-03.md).

## Штукатурка

Путь: `assets/materials/plaster-worn-v1.png`.

Исходный output: `/Users/nikolaj/.codex/generated_images/01a14055-71c6-71a1-8c61-274143cfd1e8/exec-a77b4aed-635b-4808-bba2-98f335e61381.png`.

Точный prompt:

```text
Use case: stylized-concept
Asset type: seamless square base-color material texture for a first-person indie game, not a scene, flat orthographic texture filling the entire image.
Primary request: a close surface scan of old Soviet bus terminal lime plaster: layers of desaturated grey-beige paint, broad irregular water stains, thin branching cracks, small chipped areas exposing coarse cement and faint traces of old glue. The texture is tactile and authored, in the grimy photographic paint-over visual language of No, I'm not a Human. Retain rich natural microtexture, roughly painted broad shadows and slightly posterized earthy hues. No obvious horizontal stripes and no regular grid. No simple computer noise or pixel checkerboard.
Composition: one continuous wall surface fills every pixel, seamless repeating at all four edges, no frame, no wall corners, no perspective, no object or wall signage, no text, no montage or material samples.
Lighting: perfectly diffuse even base-color lighting; no directional cast shadows, no gradient or vignette baked in.
Palette: neutral aged grey stone, faded warm ivory and a little dark brown grime, restrained saturation; no green tint. Deliver a square high-quality opaque texture, suitable for world-space tiling.
```

## Дерево

Путь: `assets/materials/walnut-worn-v1.png`.

Исходный output: `/Users/nikolaj/.codex/generated_images/01a14055-71c6-71a1-8c61-274143cfd1e8/exec-6c6d17f9-afc8-4d30-904c-76d294034abd.png`.

Точный prompt:

```text
Use case: stylized-concept
Asset type: seamless square base-color wood material for a first-person narrative game.
Primary request: one authentic old dark walnut veneer surface from a Soviet service counter, photographed straight down then roughly painted over in the tactile gritty indie visual language of No, I'm not a Human. Long organic wood grain runs vertically, varnish partly worn through to pale dusty brown raw wood, broad rubbed patches, tiny dents, hairline scratches, a few small dark ink stains. The surface must have beautiful detailed varied grain, restrained and believable; NOT plank flooring, no evenly spaced joints, no decorative frame, no objects.
Composition: one continuous texture filling every pixel, orthographic flat surface, seamlessly tileable along all four edges. Moderate local contrast, no central hero mark, no perspective.
Lighting: even diffuse base color only, no vignette, no directional light, no cast shadow.
Palette: weathered neutral brown walnut, taupe and sepia; no orange or green color cast. Opaque square material texture with rich texture and painted photographic quality. No text, logos, grids or collage.
```

## Окрашенная сталь

Путь: `assets/materials/steel-painted-v1.png`.

Исходный output: `/Users/nikolaj/.codex/generated_images/01a14055-71c6-71a1-8c61-274143cfd1e8/exec-c5a451c6-13ee-4ce2-9033-a908a6a1e202.png`.

Точный prompt:

```text
Use case: stylized-concept
Asset type: seamless square base-color painted metal texture for an authored first-person indie game.
Primary request: old institutional painted steel, dark neutral grey with a faint faded sage undertone, a dense tactile layer of brush-painted enamel with irregular tiny chips revealing dull pewter, rubbed silver scratches, accumulated dark dirt, and sparse brown oxidized pits. The surface has been touched and maintained for decades in a Soviet bus terminal. Detailed photographic surface with a rough painted-over quality in the visual language of No, I'm not a Human. Fine dense imperfections plus varied broader cloudy wear, not gigantic rust flakes.
Composition: flat orthographic surface filling every pixel, seamless repeating on all four edges. No hardware, rivets, panels, edges, frames, words, logos or objects. One material, not a contact sheet.
Lighting: perfectly even diffuse base-color texture, no lighting gradients, baked shadows or glossy highlights. Palette: neutral charcoal grey, dull grey metal, muted brown oxidation, only a very faint grey-green undertone. No vivid green, no orange dominant, no horizontal bands or repeating noise. Opaque square.
```
