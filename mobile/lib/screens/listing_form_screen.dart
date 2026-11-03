import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../api/api_client.dart';
import '../models.dart';
import '../theme.dart';
import '../utils.dart';
import '../widgets/common.dart';
import 'map_picker_screen.dart';

class ListingFormScreen extends StatefulWidget {
  const ListingFormScreen({super.key, this.existing});
  final OilListing? existing;

  @override
  State<ListingFormScreen> createState() => _ListingFormScreenState();
}

class _ListingFormScreenState extends State<ListingFormScreen> {
  final _title = TextEditingController();
  final _liters = TextEditingController();
  final _rate = TextEditingController();
  final _address = TextEditingController();
  final _area = TextEditingController();
  final _city = TextEditingController();
  final _pincode = TextEditingController();
  final _phone = TextEditingController();
  final _notes = TextEditingController();

  String _oilType = 'mixed';
  DateTime _from = DateTime.now().add(const Duration(hours: 1));
  DateTime _to = DateTime.now().add(const Duration(days: 2));
  Uint8List? _photo;
  String? _photoName;
  double? _lat;
  double? _lng;
  String? _placeLabel;
  bool _busy = false;
  bool _rateTouched = false;

  List<OilRate> _rates = [];
  final _picker = ImagePicker();

  bool get _editing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _title.text = e.title;
      _oilType = e.oilType;
      _liters.text = e.approxLiters.toStringAsFixed(e.approxLiters % 1 == 0 ? 0 : 1);
      _rate.text = e.ratePerLiter.toStringAsFixed(e.ratePerLiter % 1 == 0 ? 0 : 2);
      _address.text = e.address;
      _area.text = e.area ?? '';
      _city.text = e.city ?? '';
      _pincode.text = e.pincode ?? '';
      _phone.text = e.phone ?? '';
      _notes.text = e.notes ?? '';
      _from = e.availableFrom;
      _to = e.availableTo;
      _lat = e.lat;
      _lng = e.lng;
      _placeLabel = e.area ?? e.city;
      _rateTouched = true;
    } else {
      final u = Api.instance.user;
      _phone.text = u?.phone ?? '';
      _city.text = u?.city ?? '';
    }
    _loadRates();
  }

  @override
  void dispose() {
    for (final c in [_title, _liters, _rate, _address, _area, _city, _pincode, _phone, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadRates() async {
    try {
      final r = await Api.instance.rates();
      if (!mounted) return;
      setState(() {
        _rates = r;
        if (!_rateTouched) {
          final match = r.where((x) => x.oilType == _oilType);
          if (match.isNotEmpty) _rate.text = match.first.price.toStringAsFixed(0);
        }
      });
    } catch (_) {}
  }

  void _selectOil(String t) {
    setState(() {
      _oilType = t;
      if (!_rateTouched) {
        final match = _rates.where((x) => x.oilType == t);
        if (match.isNotEmpty) _rate.text = match.first.price.toStringAsFixed(0);
      }
    });
  }

  Future<void> _pickPhoto() async {
    try {
      final file = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 1600, imageQuality: 85);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      setState(() {
        _photo = bytes;
        _photoName = file.name;
      });
    } catch (_) {
      _snack('Could not open photos.');
    }
  }

  Future<void> _pickPlace() async {
    final picked = await Navigator.of(context).push<PickedPlace>(MaterialPageRoute(
      builder: (_) => MapPickerScreen(
        initial: _lat != null && _lng != null
            ? PickedPlace(lat: _lat!, lng: _lng!, label: _placeLabel ?? '', area: _area.text, city: _city.text, pincode: _pincode.text)
            : null,
      ),
    ));
    if (picked == null) return;
    setState(() {
      _lat = picked.lat;
      _lng = picked.lng;
      _placeLabel = picked.label;
      if (_address.text.trim().isEmpty) _address.text = picked.label;
      if (_area.text.trim().isEmpty && picked.area != null) _area.text = picked.area!;
      if (_city.text.trim().isEmpty && picked.city != null) _city.text = picked.city!;
      if (_pincode.text.trim().isEmpty && picked.pincode != null) _pincode.text = picked.pincode!;
    });
  }

  Future<DateTime?> _pickMoment(DateTime initial) async {
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 120)),
    );
    if (date == null) return null;
    if (!mounted) return null;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(initial));
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final liters = double.tryParse(_liters.text.trim());
    final rate = double.tryParse(_rate.text.trim());
    if (_title.text.trim().length < 2) return _snack('Give the load a short title');
    if (liters == null || liters <= 0) return _snack('How many litres?');
    if (rate == null || rate < 0) return _snack('Enter a rate per litre');
    if (_address.text.trim().length < 4) return _snack('Add the pickup address');
    if (_to.isBefore(_from) || _to.isAtSameMomentAs(_from)) return _snack('The pickup window must end after it starts');
    setState(() => _busy = true);
    try {
      await Api.instance.saveListing(
        id: widget.existing?.id,
        fields: {
          'title': _title.text.trim(),
          'oil_type': _oilType,
          'approx_liters': '$liters',
          'rate_per_liter': '$rate',
          'address': _address.text.trim(),
          if (_area.text.trim().isNotEmpty) 'area': _area.text.trim(),
          if (_city.text.trim().isNotEmpty) 'city': _city.text.trim(),
          if (_pincode.text.trim().isNotEmpty) 'pincode': _pincode.text.trim(),
          if (_lat != null && _lng != null) 'lat': '$_lat',
          if (_lat != null && _lng != null) 'lng': '$_lng',
          if (_phone.text.trim().isNotEmpty) 'phone': _phone.text.trim(),
          'available_from': apiDate(_from),
          'available_to': apiDate(_to),
          if (_notes.text.trim().isNotEmpty) 'notes': _notes.text.trim(),
        },
        photoBytes: _photo,
        photoName: _photoName,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      _snack(e.message);
    } catch (_) {
      _snack('Could not save. Check your connection.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  @override
  Widget build(BuildContext context) {
    final liters = double.tryParse(_liters.text) ?? 0;
    final rate = double.tryParse(_rate.text) ?? 0;
    return Scaffold(
      appBar: AppBar(title: Text(_editing ? 'Edit load' : 'List used oil')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          _PhotoBox(bytes: _photo, path: widget.existing?.photoUrl, onTap: _pickPhoto),
          const SizedBox(height: 18),
          _label('What oil is it?'),
          Wrap(spacing: 7, runSpacing: 7, children: [
            for (final t in oilTypes)
              ChoiceChip(
                label: Text('${oilEmoji(t)} ${oilLabel(t)}'),
                selected: _oilType == t,
                showCheckmark: false,
                onSelected: (_) => _selectOil(t),
              ),
          ]),
          const SizedBox(height: 18),
          _label('The load'),
          TextField(
            controller: _title,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(hintText: 'e.g. Sunflower oil after Sunday brunch', prefixIcon: Icon(Icons.edit_outlined, size: 20)),
          ),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _liters,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(hintText: 'Litres', suffixText: 'L', prefixIcon: Icon(Icons.water_drop_outlined, size: 20)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _rate,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                onChanged: (_) => setState(() => _rateTouched = true),
                decoration: const InputDecoration(hintText: 'Rate', prefixText: '₹ ', suffixText: '/L'),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          if (liters > 0 && rate > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(color: AppColors.amberSoft, borderRadius: BorderRadius.circular(14)),
              child: Row(children: [
                const Icon(Icons.calculate_outlined, size: 16, color: AppColors.amberDeep),
                const SizedBox(width: 8),
                Text('${litres(liters)} × ${money(rate)} = ${money(liters * rate)}',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
              ]),
            ),
          const SizedBox(height: 18),
          _label('Pickup window'),
          Row(children: [
            Expanded(child: _WindowTile(label: 'From', value: dayMonthTime(_from), onTap: () async {
              final d = await _pickMoment(_from);
              if (d != null) setState(() => _from = d);
            })),
            const SizedBox(width: 8),
            Expanded(child: _WindowTile(label: 'Until', value: dayMonthTime(_to), onTap: () async {
              final d = await _pickMoment(_to);
              if (d != null) setState(() => _to = d);
            })),
          ]),
          const SizedBox(height: 18),
          _label('Where should they come?'),
          TextField(
            controller: _address,
            maxLines: 2,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(hintText: 'Building, street, landmark', prefixIcon: Icon(Icons.place_outlined, size: 20)),
          ),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: TextField(controller: _area, decoration: const InputDecoration(hintText: 'Area'))),
            const SizedBox(width: 10),
            Expanded(child: TextField(controller: _city, decoration: const InputDecoration(hintText: 'City'))),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: TextField(controller: _pincode, keyboardType: TextInputType.number, decoration: const InputDecoration(hintText: 'PIN code'))),
            const SizedBox(width: 10),
            Expanded(child: TextField(controller: _phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(hintText: 'Phone'))),
          ]),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: _pickPlace,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: _lat == null ? AppColors.line : AppColors.olive.withValues(alpha: 0.45)),
              ),
              child: Row(children: [
                Icon(_lat == null ? Icons.add_location_alt_outlined : Icons.check_circle_rounded,
                    size: 20, color: _lat == null ? AppColors.muted : AppColors.olive),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(_lat == null ? 'Pin on map (recommended)' : 'Pinned on map',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    Text(
                      _lat == null
                          ? 'Our pickup team sees distance and gets Google Maps directions.'
                          : (_placeLabel ?? '${_lat!.toStringAsFixed(5)}, ${_lng!.toStringAsFixed(5)}'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 10.5, color: AppColors.muted),
                    ),
                  ]),
                ),
                const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.muted),
              ]),
            ),
          ),
          const SizedBox(height: 18),
          _label('Notes for the pickup team (optional)'),
          TextField(
            controller: _notes,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(hintText: 'Storage spot, gate code, best time to call…'),
          ),
          const SizedBox(height: 22),
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: _busy
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                : Text(_editing ? 'Save changes' : 'Put it on the radar'),
          ),
          const SizedBox(height: 10),
          const Center(
            child: Text('Free to list. You agree the rate with the pickup team at collection.',
                style: TextStyle(fontSize: 10.5, color: AppColors.muted)),
          ),
        ],
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8, left: 2),
        child: Text(text.toUpperCase(),
            style: const TextStyle(fontSize: 10, letterSpacing: 1.2, fontWeight: FontWeight.w800, color: AppColors.muted)),
      );
}

class _PhotoBox extends StatelessWidget {
  const _PhotoBox({required this.bytes, required this.onTap, this.path});
  final Uint8List? bytes;
  final String? path;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasImage = bytes != null || (path != null && path!.isNotEmpty);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 168,
        decoration: BoxDecoration(
          color: AppColors.amberSoft,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.amber.withValues(alpha: 0.4)),
        ),
        clipBehavior: Clip.antiAlias,
        child: hasImage
            ? Stack(fit: StackFit.expand, children: [
                if (bytes != null)
                  Image.memory(bytes!, fit: BoxFit.cover)
                else
                  OilPhoto(path, height: 168, radius: 0),
                Positioned(
                  right: 10,
                  bottom: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(20)),
                    child: const Row(children: [
                      Icon(Icons.photo_camera_rounded, size: 13, color: Colors.white),
                      SizedBox(width: 5),
                      Text('Change photo', style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w700)),
                    ]),
                  ),
                ),
              ])
            : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                const DropMark(size: 42),
                const SizedBox(height: 8),
                const Text('Add a photo of the oil / cans',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(height: 2),
                Text('Optional, but loads with a photo get claimed faster',
                    style: TextStyle(fontSize: 10.5, color: AppColors.muted.withValues(alpha: 0.9))),
              ]),
      ),
    );
  }
}

class _WindowTile extends StatelessWidget {
  const _WindowTile({required this.label, required this.value, required this.onTap});
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.line)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label.toUpperCase(),
              style: const TextStyle(fontSize: 8.5, letterSpacing: 1, fontWeight: FontWeight.w800, color: AppColors.muted)),
          const SizedBox(height: 4),
          Row(children: [
            const Icon(Icons.schedule_rounded, size: 13, color: AppColors.amberDeep),
            const SizedBox(width: 4),
            Expanded(
              child: Text(value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
            ),
          ]),
        ]),
      ),
    );
  }
}
