import '../../media/reciter_photos.dart';

/// Which reciter photo (`assets/reciters/<key>.jpg`, and its small copy
/// `drawable/car_r_<key>` for Android Auto) belongs to a reciter id.
class ReciterArt {
  ReciterArt._();

  /// The per-ayah reciters (the Mushaf's) mapped to the photo keys of the
  /// full-surah catalog.
  static const _ayah = {
    'ar.alafasy': 'afs',
    'ar.abdulbasitmurattal': 'basit',
    'ar.husary': 'husr',
    'ar.husarymujawwad': 'husr',
    'ar.minshawi': 'minsh',
    'ar.abdurrahmaansudais': 'sds',
    'ar.saoodshuraym': 'shur',
    'ar.mahermuaiqly': 'maher',
    'ar.ahmedajamy': 'ajm',
    'ar.shaatree': 'shatri',
    'ar.hudhaify': 'hthfi',
    'ar.muhammadayyoub': 'ayyub',
    'ar.abdullahbasfar': 'bsfr',
    'ar.hanirifai': 'hani',
    'ar.muhammadjibreel': 'jbrl',
  };

  /// The photo key for a catalog key ('minsh_mj'), a queue id ('mp3q:minsh')
  /// or a per-ayah reciter id ('ar.minshawi'); null when there is no photo.
  static String? keyFor(String? id) {
    if (id == null) return null;
    var k = _ayah[id] ?? (id.startsWith('mp3q:') ? id.substring(5) : id);
    k = k.replaceAll('_mj', '');
    return kReciterPhotos.contains(k) ? k : null;
  }
}
