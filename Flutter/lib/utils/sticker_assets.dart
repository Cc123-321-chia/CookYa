// lib/utils/sticker_assets.dart

class StickerAsset {
  final String id;
  final String name;
  final String assetPath;

  const StickerAsset({
    required this.id,
    required this.name,
    required this.assetPath,
  });
}

const List<StickerAsset> kStickerAssets = [
  StickerAsset(
    id: 'delicious',
    name: 'Delicious',
    assetPath: 'assets/stickers/sticker_delicious.jpeg',
  ),
  StickerAsset(
    id: 'disgusting',
    name: 'Disgusting',
    assetPath: 'assets/stickers/sticker_disgusting.jpeg',
  ),
  StickerAsset(
    id: 'meh',
    name: 'Meh',
    assetPath: 'assets/stickers/sticker_meh.jpeg',
  ),
  StickerAsset(
    id: 'happy',
    name: 'Happy',
    assetPath: 'assets/stickers/sticker_happy.jpeg',
  ),
  StickerAsset(
    id: 'encourage',
    name: 'Encourage',
    assetPath: 'assets/stickers/sticker_encourage.jpeg',
  ),
  StickerAsset(
    id: 'angry',
    name: 'Angry',
    assetPath: 'assets/stickers/sticker_angry.jpeg',
  ),
  StickerAsset(
    id: 'troubled',
    name: 'Troubled',
    assetPath: 'assets/stickers/sticker_troubled.jpeg',
  ),
  StickerAsset(
    id: 'shocked',
    name: 'Shocked',
    assetPath: 'assets/stickers/sticker_shocked.jpeg',
  ),
  StickerAsset(
    id: 'cooking',
    name: 'Cooking',
    assetPath: 'assets/stickers/sticker_cooking.jpeg',
  ),
  StickerAsset(
    id: 'proud',
    name: 'Proud',
    assetPath: 'assets/stickers/sticker_proud.jpeg',
  ),
];

StickerAsset? stickerById(String id) {
  try {
    return kStickerAssets.firstWhere((s) => s.id == id);
  } catch (_) {
    return null;
  }
}