import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import '../models/admin_models.dart';
import '../services/admin_service.dart';

class AdsScreen extends StatefulWidget {
  const AdsScreen({super.key});

  @override
  State<AdsScreen> createState() => _AdsScreenState();
}

class _AdsScreenState extends State<AdsScreen> {
  final AdminService _service = AdminService();

  bool _loading = false;
  String? _error;
  List<AdminAd> _ads = [];

  @override
  void initState() {
    super.initState();
    _loadAds();
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _fmtDate(DateTime? dt) {
    if (dt == null) return '—';
    final s = dt.toLocal().toString();
    return s.split('.').first;
  }

  Future<void> _loadAds() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final list = await _service.fetchAds();
      setState(() => _ads = list);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _deleteAd(AdminAd ad) async {
    final ok = await _confirmDialog(
      title: 'Delete ad?',
      body: 'Delete "${ad.title}" permanently?\n\nNo undo 😬',
      danger: true,
    );
    if (!ok) return;

    setState(() => _loading = true);
    try {
      await _service.deleteAd(ad.id);
      _toast('Ad deleted ✅');
      await _loadAds();
    } catch (e) {
      _toast('Delete failed: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openUploadDialog() async {
    final titleCtrl = TextEditingController();
    final msgCtrl = TextEditingController();
    final linkCtrl = TextEditingController();
    final weightCtrl = TextEditingController();

    bool active = true;
    PlatformFile? largeImage;
    PlatformFile? smallWebImage;
    PlatformFile? thumbImage;

    Future<PlatformFile?> pickImage() async {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
        withData: true,
      );
      return res?.files.single;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            void refresh() => setLocal(() {});

            String fileName(PlatformFile? f) =>
                f == null ? '(not selected)' : f.name;

            return AlertDialog(
              title: const Text('Upload New Ad'),
              content: SizedBox(
                width: 560,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      TextField(
                        controller: titleCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Title',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: msgCtrl,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Message (optional)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: linkCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Link URL (optional)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: weightCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Weight (optional)',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: SwitchListTile(
                              value: active,
                              onChanged: (v) {
                                active = v;
                                refresh();
                              },
                              title: const Text('Active'),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 26),

                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Upload specs:',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Large ad (required, full/open view): 1920x1080 (16:9) preferred, minimum 1600x900.',
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Small web ad (homepage strips, app shell web strips): 1366x768 preferred, minimum 960x540.',
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Card/thumb ad (Ads tab cards): 1280x720 preferred, minimum 960x540.',
                        ),
                      ),
                      const Divider(height: 24),

                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Large image (homepage): ${fileName(largeImage)}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 10),
                          OutlinedButton.icon(
                            onPressed: () async {
                              final f = await pickImage();
                              if (f == null) return;
                              largeImage = f;
                              refresh();
                            },
                            icon: const Icon(Icons.image),
                            label: const Text('Pick large'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Small web image: ${fileName(smallWebImage)}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 10),
                          OutlinedButton.icon(
                            onPressed: () async {
                              final f = await pickImage();
                              if (f == null) return;
                              smallWebImage = f;
                              refresh();
                            },
                            icon: const Icon(Icons.web),
                            label: const Text('Pick small'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Thumb 16:9 (optional): ${fileName(thumbImage)}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 10),
                          OutlinedButton.icon(
                            onPressed: () async {
                              final f = await pickImage();
                              if (f == null) return;
                              thumbImage = f;
                              refresh();
                            },
                            icon: const Icon(Icons.photo_size_select_large),
                            label: const Text('Pick thumb'),
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),
                      const Text(
                        'Legend: Large = fullscreen/detail, Small web = website rotating strips, Thumb = ads list cards. Max 12MB each.',
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    if (titleCtrl.text.trim().isEmpty) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(content: Text('Title is required.')),
                      );
                      return;
                    }
                    if (largeImage == null || largeImage?.bytes == null) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(
                          content: Text('Pick a LARGE homepage image.'),
                        ),
                      );
                      return;
                    }
                    Navigator.pop(ctx, true);
                  },
                  child: const Text('Upload'),
                ),
              ],
            );
          },
        );
      },
    );

    if (ok != true) {
      titleCtrl.dispose();
      msgCtrl.dispose();
      linkCtrl.dispose();
      weightCtrl.dispose();
      return;
    }

    setState(() => _loading = true);
    try {
      final weight = int.tryParse(weightCtrl.text.trim()) ?? 0;

      await _service.uploadAd(
        title: titleCtrl.text.trim(),
        message: msgCtrl.text.trim().isEmpty ? null : msgCtrl.text.trim(),
        linkUrl: linkCtrl.text.trim().isEmpty ? null : linkCtrl.text.trim(),
        active: active,
        weight: weight, // int? (leave null if empty)
        imageBytes: largeImage!.bytes!,
        imageName: largeImage!.name,
        smallBytes: smallWebImage?.bytes,
        smallName: smallWebImage?.name,
        thumbBytes: (thumbImage ?? largeImage)!.bytes!,
        thumbName: (thumbImage ?? largeImage)!.name,
      );

      _toast('Ad uploaded ✅');
      await _loadAds();
    } catch (e) {
      _toast('Upload failed: $e');
      if (mounted) setState(() => _loading = false);
    } finally {
      titleCtrl.dispose();
      msgCtrl.dispose();
      linkCtrl.dispose();
      weightCtrl.dispose();
    }
  }

  Future<bool> _confirmDialog({
    required String title,
    required String body,
    bool danger = false,
  }) async {
    final res = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: danger
                ? FilledButton.styleFrom(backgroundColor: Colors.redAccent)
                : null,
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    return res ?? false;
  }

  Widget _thumbBox(String url) {
    const w = 130.0;
    const h = 74.0; // ~16:9

    if (url.trim().isEmpty) {
      return Container(
        width: w,
        height: h,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.black12,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.black12),
        ),
        child: const Icon(Icons.image_not_supported),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: w,
        height: h,
        color: Colors.black12,
        child: Image.network(
          url,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) =>
              const Center(child: Icon(Icons.broken_image)),
          loadingBuilder: (ctx, child, prog) {
            if (prog == null) return child;
            return const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            );
          },
        ),
      ),
    );
  }

  Future<void> _openPreview(AdminAd ad) async {
    final img = (ad.imageUrl ?? ad.thumbUrl ?? '').trim();
    if (img.isEmpty) return;

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(ad.title),
        content: SizedBox(
          width: 900,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    img,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) =>
                        const Center(child: Icon(Icons.broken_image)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if ((ad.message ?? '').trim().isNotEmpty)
                Text(ad.message!.trim()),
              const SizedBox(height: 8),
              Text(
                'Active: ${ad.active ? "Yes" : "No"} • Created: ${_fmtDate(ad.createdAt)}',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ads Manager'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _loadAds,
            icon: const Icon(Icons.refresh),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: _loading ? null : _openUploadDialog,
            icon: const Icon(Icons.upload),
            label: const Text('Upload'),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.black12,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.black12),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ad upload resolutions',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 4),
                Text(
                  'Large/Homepage (required): 1920x1080 preferred, minimum 1600x900.',
                ),
                Text(
                  'Card/Thumb (recommended): 1280x720 preferred, minimum 960x540.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? Center(child: Text('Error: $_error'))
                : _ads.isEmpty
                ? const Center(child: Text('No ads yet. Upload one 😄'))
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: _ads.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final ad = _ads[i];
                      final img = (ad.thumbUrl ?? ad.imageUrl ?? '').trim();

                      return Card(
                        child: ListTile(
                          leading: _thumbBox(img),
                          title: Text(ad.title),
                          subtitle: Text(
                            [
                              ad.active ? 'ACTIVE' : 'INACTIVE',
                              if ((ad.weight ?? 0) > 0) 'weight=${ad.weight}',
                              if ((ad.linkUrl ?? '').trim().isNotEmpty)
                                'link set',
                            ].join(' • '),
                          ),
                          onTap: () => _openPreview(ad),
                          trailing: IconButton(
                            tooltip: 'Delete',
                            onPressed: () => _deleteAd(ad),
                            icon: const Icon(
                              Icons.delete,
                              color: Colors.redAccent,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
