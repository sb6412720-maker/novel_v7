/// Bundled cover images from `story_card_images/` (declared in pubspec assets).
/// Used so every story card always shows a cover even when API cover_path is empty.
class CoverAssets {
  CoverAssets._();

  static const List<String> paths = [
    'story_card_images/006575b1-f6b5-49b2-b3a4-6a9ef1a1e02e.jpg',
    'story_card_images/04d68518-aafb-497e-995e-10bc6e4bef90.jpg',
    'story_card_images/0aaa5ea7-670f-4995-8378-474c09b319b2.jpg',
    'story_card_images/0d88ca6e-bdb9-4d45-b7f4-013f0ef843e5.jpg',
    'story_card_images/19eb26e8-6ee4-4010-8848-8f5779f602dd.jpg',
    'story_card_images/32b84f85-8e95-4a2d-8674-f3dc957133c8.jpg',
    'story_card_images/3379b80d-dc86-4a35-9a05-926f8b2cbbc5.jpg',
    'story_card_images/4803aa58-6dc5-4816-b1d7-3d955156f1ca.jpg',
    'story_card_images/4a4f19a1-b096-4613-b635-f71e311481d1.jpg',
    'story_card_images/5ba33f5b-f733-4dd3-a3d8-ad66dacfb093.jpg',
    'story_card_images/60bf539d-3d16-4f7b-bda6-bb0bc5bd8385.jpg',
    'story_card_images/6290b4c8-83e9-4d5d-a740-06d4ec94d335.jpg',
    'story_card_images/6a5c2a85-2d8c-498d-9153-1d72ec4005e4.jpg',
    'story_card_images/7d7d5cc8-5b0a-4821-9e57-3f58c36998b0.jpg',
    'story_card_images/8de846ae-c1cc-4e8b-a52e-e8aa48b6abb1.jpg',
    'story_card_images/9e84fd30-5477-45f2-8c48-5c290f275856.jpg',
    'story_card_images/a16e9738-0207-421b-84ac-f9c7193f77df.jpg',
    'story_card_images/a5f489f6-2a42-43c0-a190-2da06adfebf8.jpg',
    'story_card_images/b38a56a4-02f3-4d51-aa3e-469b25e77806.jpg',
    'story_card_images/c1a4b2d2-7ba9-44ea-9ea9-81873119a8ec.jpg',
    'story_card_images/cf12c459-4fe5-4725-8ca0-01f42b898d21.jpg',
    'story_card_images/d1a0655f-892d-4603-919f-92cdf779dae7.jpg',
    'story_card_images/d55997d3-bc48-43a1-a42e-d004598104d0.jpg',
    'story_card_images/d7728b65-7fcc-45cc-bfb2-38a47dfea216.jpg',
    'story_card_images/dc335f4a-9cf3-498d-8c27-5addd0cb15cf.jpg',
    'story_card_images/dc499710-91bd-4dae-8d0c-145faa5345e2.jpg',
    'story_card_images/de52e8d5-1a1c-43b2-8752-70582d3e6c94.jpg',
    'story_card_images/e65f5659-9564-4623-b4c6-a5c37cb4aa5e.jpg',
    'story_card_images/fdc309b2-20b4-4966-8293-9db4532dd8e3.jpg',
  ];

  /// Deterministic pick from seed (book id / title hash) so the same story
  /// keeps the same fallback cover across rebuilds.
  static String assetForSeed(int seed) {
    if (paths.isEmpty) return '';
    final i = seed.abs() % paths.length;
    return paths[i];
  }

  static String assetForKey(String key) {
    final h = key.hashCode;
    return assetForSeed(h == 0 ? 1 : h);
  }
}
