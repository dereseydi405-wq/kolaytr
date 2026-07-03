import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LifeTask {
  final String id;
  final String title;
  final String description;

  const LifeTask({
    required this.id,
    required this.title,
    required this.description,
  });
}

class LifeEvent {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final List<LifeTask> tasks;

  const LifeEvent({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.tasks,
  });
}

const List<LifeEvent> lifeEvents = [
  LifeEvent(
    id: 'bebegim_oldu',
    title: 'Bebeğim Oldu',
    description:
        'Doğum sonrası kimlik, sağlık ve sosyal destek adımlarını takip et.',
    icon: Icons.child_care_rounded,
    color: Color(0xFFEC4899),
    tasks: [
      LifeTask(
        id: 'dogum',
        title: 'Doğum bildirimi sürecini kontrol et',
        description: 'Hastane bildirimi ve nüfus kaydı sürecini takip et.',
      ),
      LifeTask(
        id: 'kimlik',
        title: 'Bebek için kimlik çıkarma adımlarını tamamla',
        description: 'Gerekli belgeleri ve başvuru kanalını kontrol et.',
      ),
      LifeTask(
        id: 'saglik',
        title: 'Aile hekimi ve sağlık kayıtlarını kontrol et',
        description: 'Aşı, aile hekimi ve sağlık takip adımlarını not al.',
      ),
      LifeTask(
        id: 'destek',
        title: 'Sosyal yardım haklarını incele',
        description: 'Çocuk yardımı veya ilgili destekleri kontrol et.',
      ),
    ],
  ),
  LifeEvent(
    id: 'evlenecegim',
    title: 'Evleneceğim',
    description:
        'Nikâh, belge, kimlik ve adres işlemlerini tek listede takip et.',
    icon: Icons.favorite_rounded,
    color: Color(0xFFEF4444),
    tasks: [
      LifeTask(
        id: 'nikah',
        title: 'Nikâh başvurusu için belgeleri hazırla',
        description: 'Başvuru şartlarını ve gerekli evrakları kontrol et.',
      ),
      LifeTask(
        id: 'saglik_raporu',
        title: 'Sağlık raporu sürecini kontrol et',
        description:
            'Evlilik başvurusu için istenen sağlık adımlarını takip et.',
      ),
      LifeTask(
        id: 'kimlik',
        title: 'Kimlik bilgilerini güncelleme gerekliliğini kontrol et',
        description: 'Soyadı veya medeni durum değişikliği varsa not al.',
      ),
      LifeTask(
        id: 'adres',
        title: 'Adres değişikliği gerekiyorsa işlem başlat',
        description: 'Yeni adres bilgilerini kontrol et.',
      ),
    ],
  ),
  LifeEvent(
    id: 'arac_aldim',
    title: 'Araç Aldım',
    description: 'Ruhsat, sigorta, MTV, muayene ve HGS adımlarını takip et.',
    icon: Icons.directions_car_filled_rounded,
    color: Color(0xFF2563EB),
    tasks: [
      LifeTask(
        id: 'ruhsat',
        title: 'Ruhsat işlemlerini kontrol et',
        description: 'Araç devri sonrası ruhsat ve tescil durumunu takip et.',
      ),
      LifeTask(
        id: 'sigorta',
        title: 'Zorunlu trafik sigortasını kontrol et',
        description: 'Sigorta başlangıç ve bitiş tarihlerini not al.',
      ),
      LifeTask(
        id: 'mtv',
        title: 'MTV borcu ve ödeme dönemlerini incele',
        description: 'Motorlu Taşıtlar Vergisi dönemlerini takip et.',
      ),
      LifeTask(
        id: 'muayene',
        title: 'Araç muayene tarihini kontrol et',
        description: 'Muayene tarihini not al ve hatırlatıcı oluştur.',
      ),
      LifeTask(
        id: 'hgs',
        title: 'HGS/OGS durumunu kontrol et',
        description: 'Köprü ve otoyol geçişleri için kayıt durumunu incele.',
      ),
    ],
  ),
  LifeEvent(
    id: 'ev_aldim',
    title: 'Ev Satın Aldım',
    description: 'Tapu, vergi, abonelik ve adres işlemlerini planla.',
    icon: Icons.home_work_rounded,
    color: Color(0xFF0F766E),
    tasks: [
      LifeTask(
        id: 'tapu',
        title: 'Tapu işlemlerini kontrol et',
        description: 'Tapu kaydı, harç ve başvuru adımlarını takip et.',
      ),
      LifeTask(
        id: 'vergi',
        title: 'Emlak vergisi durumunu incele',
        description: 'Belediye ve ödeme dönemlerini not al.',
      ),
      LifeTask(
        id: 'abonelik',
        title: 'Elektrik, su ve doğalgaz aboneliklerini planla',
        description: 'Yeni abonelik veya devir işlemlerini sıraya koy.',
      ),
      LifeTask(
        id: 'adres',
        title: 'Adres değişikliği bildirimi yap',
        description: 'Yeni adresini resmi kayıtlarda güncelle.',
      ),
    ],
  ),
  LifeEvent(
    id: 'ise_basladim',
    title: 'Yeni İşe Başladım',
    description: 'SGK, banka, belgeler ve çalışma hayatı adımlarını takip et.',
    icon: Icons.work_rounded,
    color: Color(0xFF7C3AED),
    tasks: [
      LifeTask(
        id: 'sgk',
        title: 'SGK işe girişini kontrol et',
        description: 'Hizmet dökümü ve işe giriş bildirgesini kontrol et.',
      ),
      LifeTask(
        id: 'banka',
        title: 'Maaş hesabı bilgilerini hazırla',
        description: 'İşverenin istediği banka veya IBAN bilgilerini not al.',
      ),
      LifeTask(
        id: 'belgeler',
        title: 'İstenen belgeleri hazırla',
        description:
            'Kimlik, ikametgâh, adli sicil ve sağlık raporu gibi evrakları kontrol et.',
      ),
      LifeTask(
        id: 'vergi',
        title: 'Vergi ve gelir durumunu kontrol et',
        description: 'Maaş ve çalışma bilgilerini takip et.',
      ),
    ],
  ),
  LifeEvent(
    id: 'tasiniyorum',
    title: 'Taşınıyorum',
    description:
        'Adres, abonelik, okul, sağlık ve belge değişikliklerini yönet.',
    icon: Icons.local_shipping_rounded,
    color: Color(0xFFF59E0B),
    tasks: [
      LifeTask(
        id: 'adres',
        title: 'Adres değişikliği bildirimi yap',
        description: 'Yeni adresini resmi kayıtlara işle.',
      ),
      LifeTask(
        id: 'abonelik',
        title: 'Abonelikleri taşı veya kapat',
        description: 'Elektrik, su, doğalgaz ve internet işlemlerini planla.',
      ),
      LifeTask(
        id: 'okul',
        title: 'Okul veya öğrenci kayıtlarını kontrol et',
        description: 'Çocuk varsa okul nakil ve kayıt durumunu incele.',
      ),
      LifeTask(
        id: 'saglik',
        title: 'Aile hekimi değişikliğini kontrol et',
        description: 'Yeni adresine göre aile hekimi durumunu incele.',
      ),
    ],
  ),
];

class LifeEventStore {
  static String key(String eventId) => 'kolaytr_life_event_$eventId';

  static Future<Set<String>> load(String eventId) async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(key(eventId)) ?? <String>[]).toSet();
  }

  static Future<void> save(String eventId, Set<String> completed) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(key(eventId), completed.toList());
  }
}

class LifeEventsHomeCard extends StatefulWidget {
  const LifeEventsHomeCard({super.key});

  @override
  State<LifeEventsHomeCard> createState() => _LifeEventsHomeCardState();
}

class _LifeEventsHomeCardState extends State<LifeEventsHomeCard> {
  int completedCount = 0;
  int totalCount = 0;

  @override
  void initState() {
    super.initState();
    loadProgress();
  }

  Future<void> loadProgress() async {
    var completed = 0;
    var total = 0;

    for (final event in lifeEvents) {
      final eventCompleted = await LifeEventStore.load(event.id);
      completed += eventCompleted.length;
      total += event.tasks.length;
    }

    if (!mounted) return;

    setState(() {
      completedCount = completed;
      totalCount = total;
    });
  }

  @override
  Widget build(BuildContext context) {
    final progress = totalCount == 0 ? 0.0 : completedCount / totalCount;

    return InkWell(
      borderRadius: BorderRadius.circular(26),
      onTap: () async {
        await Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const LifeEventsPage()));
        await loadProgress();
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF7ED),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: const Color(0xFFFED7AA)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.flag_circle_rounded,
                  color: Color(0xFFEA580C),
                  size: 32,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Hayat Olayları',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                  ),
                ),
                Icon(Icons.chevron_right_rounded),
              ],
            ),
            const SizedBox(height: 10),
            const Text(
              'Bebeğim oldu, araç aldım, taşınıyorum gibi önemli süreçleri görev listesiyle takip et.',
              style: TextStyle(fontSize: 15, height: 1.35),
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                minHeight: 8,
                value: progress,
                backgroundColor: const Color(0xFFFFEDD5),
                color: const Color(0xFFEA580C),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$completedCount / $totalCount görev tamamlandı',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class LifeEventsPage extends StatefulWidget {
  const LifeEventsPage({super.key});

  @override
  State<LifeEventsPage> createState() => _LifeEventsPageState();
}

class _LifeEventsPageState extends State<LifeEventsPage> {
  final Map<String, Set<String>> completedByEvent = {};
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadAll();
  }

  Future<void> loadAll() async {
    final result = <String, Set<String>>{};

    for (final event in lifeEvents) {
      result[event.id] = await LifeEventStore.load(event.id);
    }

    if (!mounted) return;

    setState(() {
      completedByEvent
        ..clear()
        ..addAll(result);
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FC),
      appBar: AppBar(
        title: const Text(
          'Hayat Olayları',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
              children: [
                Text(
                  'Önemli yaşam süreçlerini adım adım takip et.',
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 15),
                ),
                const SizedBox(height: 18),
                ...lifeEvents.map((event) {
                  final completed = completedByEvent[event.id] ?? <String>{};
                  final progress = event.tasks.isEmpty
                      ? 0.0
                      : completed.length / event.tasks.length;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(24),
                      onTap: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => LifeEventDetailPage(event: event),
                          ),
                        );
                        await loadAll();
                      },
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: Colors.black.withOpacity(0.06),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 54,
                              height: 54,
                              decoration: BoxDecoration(
                                color: event.color.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Icon(
                                event.icon,
                                color: event.color,
                                size: 30,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    event.title,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    event.description,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(999),
                                    child: LinearProgressIndicator(
                                      minHeight: 7,
                                      value: progress,
                                      backgroundColor: event.color.withOpacity(
                                        0.10,
                                      ),
                                      color: event.color,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '${completed.length}/${event.tasks.length} görev tamamlandı',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right_rounded),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
    );
  }
}

class LifeEventDetailPage extends StatefulWidget {
  final LifeEvent event;

  const LifeEventDetailPage({super.key, required this.event});

  @override
  State<LifeEventDetailPage> createState() => _LifeEventDetailPageState();
}

class _LifeEventDetailPageState extends State<LifeEventDetailPage> {
  Set<String> completed = {};
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadCompleted();
  }

  Future<void> loadCompleted() async {
    final result = await LifeEventStore.load(widget.event.id);

    if (!mounted) return;

    setState(() {
      completed = result;
      loading = false;
    });
  }

  Future<void> toggleTask(LifeTask task, bool value) async {
    final next = completed.toSet();

    if (value) {
      next.add(task.id);
    } else {
      next.remove(task.id);
    }

    await LifeEventStore.save(widget.event.id, next);

    if (!mounted) return;

    setState(() {
      completed = next;
    });
  }

  @override
  Widget build(BuildContext context) {
    final progress = widget.event.tasks.isEmpty
        ? 0.0
        : completed.length / widget.event.tasks.length;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FC),
      appBar: AppBar(
        title: Text(
          widget.event.title,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: widget.event.color,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(widget.event.icon, color: Colors.white, size: 42),
                      const SizedBox(height: 14),
                      Text(
                        widget.event.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.event.description,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 18),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          minHeight: 9,
                          value: progress,
                          backgroundColor: Colors.white.withOpacity(0.25),
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '%${(progress * 100).round()} tamamlandı',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Görevler',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 10),
                ...widget.event.tasks.map((task) {
                  final checked = completed.contains(task.id);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: Colors.black.withOpacity(0.06)),
                    ),
                    child: CheckboxListTile(
                      value: checked,
                      onChanged: (value) => toggleTask(task, value ?? false),
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(
                        task.title,
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          decoration: checked
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                      subtitle: Text(task.description),
                    ),
                  );
                }),
              ],
            ),
    );
  }
}
