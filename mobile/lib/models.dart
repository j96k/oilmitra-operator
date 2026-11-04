import 'dart:math' as math;

/// Everything the app shows comes from these models (server JSON -> Dart).

double? _d(dynamic v) => (v as num?)?.toDouble();
int? _i(dynamic v) => (v as num?)?.toInt();
DateTime? _dt(dynamic v) => v == null ? null : DateTime.tryParse(v.toString());

class AppUser {
  AppUser({
    required this.id,
    required this.username,
    required this.name,
    required this.role,
    required this.orgType,
    this.phone,
    this.city,
    this.avatarUrl,
    this.isAdmin = false,
  });

  final int id;
  final String username;
  final String name;
  final String role; // supplier | admin
  final String orgType;
  final String? phone;
  final String? city;
  final String? avatarUrl;
  final bool isAdmin;

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
        id: _i(j['id']) ?? 0,
        username: j['username'] ?? '',
        name: j['name'] ?? '',
        role: j['role'] ?? 'supplier',
        orgType: j['org_type'] ?? 'other',
        phone: j['phone'],
        city: j['city'],
        avatarUrl: j['avatar_url'],
        isAdmin: j['is_admin'] == true,
      );
}

class OilRate {
  OilRate({required this.oilType, required this.price});
  final String oilType;
  final double price;

  factory OilRate.fromJson(Map<String, dynamic> j) =>
      OilRate(oilType: j['oil_type'] ?? 'mixed', price: _d(j['price_per_liter']) ?? 0);
}

class Pickup {
  Pickup({
    required this.id,
    required this.listingId,
    required this.listingTitle,
    required this.oilType,
    this.city,
    required this.supplierId,
    required this.supplierName,
    required this.supplierOrgType,
    this.supplierPhone,
    required this.collectorId,
    required this.collectorName,
    this.collectorPhone,
    required this.status,
    this.scheduledAt,
    this.collectedAt,
    this.actualLiters,
    this.ratePerLiter,
    this.amount,
    this.notes,
    this.rating,
    this.review,
    this.receiptPath,
    required this.createdAt,
  });

  final int id;
  final int listingId;
  final String listingTitle;
  final String oilType;
  final String? city;
  final int supplierId;
  final String supplierName;
  final String supplierOrgType;
  final String? supplierPhone;
  final int collectorId;
  final String collectorName;
  final String? collectorPhone;
  final String status; // scheduled | completed | cancelled
  final DateTime? scheduledAt;
  final DateTime? collectedAt;
  final double? actualLiters;
  final double? ratePerLiter;
  final double? amount;
  final String? notes;
  final int? rating;
  final String? review;
  final String? receiptPath;
  final DateTime createdAt;

  factory Pickup.fromJson(Map<String, dynamic> j) => Pickup(
        id: _i(j['id']) ?? 0,
        listingId: _i(j['listing_id']) ?? 0,
        listingTitle: j['listing_title'] ?? '',
        oilType: j['oil_type'] ?? 'mixed',
        city: j['city'],
        supplierId: _i(j['supplier_id']) ?? 0,
        supplierName: j['supplier_name'] ?? '',
        supplierOrgType: j['supplier_org_type'] ?? 'other',
        supplierPhone: j['supplier_phone'],
        collectorId: _i(j['collector_id']) ?? 0,
        collectorName: j['collector_name'] ?? '',
        collectorPhone: j['collector_phone'],
        status: j['status'] ?? 'scheduled',
        scheduledAt: _dt(j['scheduled_at']),
        collectedAt: _dt(j['collected_at']),
        actualLiters: _d(j['actual_liters']),
        ratePerLiter: _d(j['rate_per_liter']),
        amount: _d(j['amount']),
        notes: j['notes'],
        rating: _i(j['rating']),
        review: j['review'],
        receiptPath: j['receipt_path'],
        createdAt: _dt(j['created_at']) ?? DateTime.now(),
      );
}

class OilListing {
  OilListing({
    required this.id,
    required this.supplierId,
    required this.supplierName,
    required this.supplierOrgType,
    this.supplierPhone,
    this.supplierAvatar,
    required this.title,
    required this.oilType,
    required this.approxLiters,
    required this.ratePerLiter,
    required this.estValue,
    this.photoUrl,
    required this.address,
    this.area,
    this.city,
    this.pincode,
    this.lat,
    this.lng,
    this.phone,
    required this.availableFrom,
    required this.availableTo,
    this.notes,
    required this.status,
    this.distanceKm,
    required this.createdAt,
    this.activePickup,
    this.isMine = false,
    this.canClaim = false,
    this.canCollect = false,
  });

  final int id;
  final int supplierId;
  final String supplierName;
  final String supplierOrgType;
  final String? supplierPhone;
  final String? supplierAvatar;
  final String title;
  final String oilType;
  final double approxLiters;
  final double ratePerLiter;
  final double estValue;
  final String? photoUrl;
  final String address;
  final String? area;
  final String? city;
  final String? pincode;
  final double? lat;
  final double? lng;
  final String? phone;
  final DateTime availableFrom;
  final DateTime availableTo;
  final String? notes;
  final String status; // open | claimed | collected | cancelled | expired
  final double? distanceKm;
  final DateTime createdAt;
  final Pickup? activePickup;
  final bool isMine;
  final bool canClaim;
  final bool canCollect;

  bool get hasLocation => lat != null && lng != null;

  factory OilListing.fromJson(Map<String, dynamic> j) => OilListing(
        id: _i(j['id']) ?? 0,
        supplierId: _i(j['supplier_id']) ?? 0,
        supplierName: j['supplier_name'] ?? '',
        supplierOrgType: j['supplier_org_type'] ?? 'other',
        supplierPhone: j['supplier_phone'],
        supplierAvatar: j['supplier_avatar'],
        title: j['title'] ?? '',
        oilType: j['oil_type'] ?? 'mixed',
        approxLiters: _d(j['approx_liters']) ?? 0,
        ratePerLiter: _d(j['rate_per_liter']) ?? 0,
        estValue: _d(j['est_value']) ?? 0,
        photoUrl: j['photo_url'],
        address: j['address'] ?? '',
        area: j['area'],
        city: j['city'],
        pincode: j['pincode'],
        lat: _d(j['lat']),
        lng: _d(j['lng']),
        phone: j['phone'],
        availableFrom: _dt(j['available_from']) ?? DateTime.now(),
        availableTo: _dt(j['available_to']) ?? DateTime.now(),
        notes: j['notes'],
        status: j['status'] ?? 'open',
        distanceKm: _d(j['distance_km']),
        createdAt: _dt(j['created_at']) ?? DateTime.now(),
        activePickup: j['active_pickup'] == null ? null : Pickup.fromJson(j['active_pickup']),
        isMine: j['is_mine'] == true,
        canClaim: j['can_claim'] == true,
        canCollect: j['can_collect'] == true,
      );
}

class Impact {
  Impact({
    required this.liters,
    required this.co2Kg,
    required this.biodieselL,
    required this.carKm,
    required this.pickups,
  });

  final double liters;
  final double co2Kg;
  final double biodieselL;
  final double carKm;
  final int pickups;

  factory Impact.fromJson(Map<String, dynamic> j) => Impact(
        liters: _d(j['liters']) ?? 0,
        co2Kg: _d(j['co2_kg']) ?? 0,
        biodieselL: _d(j['biodiesel_l']) ?? 0,
        carKm: _d(j['car_km']) ?? 0,
        pickups: _i(j['pickups']) ?? 0,
      );
}

class LeaderRow {
  LeaderRow({
    required this.rank,
    required this.name,
    required this.orgType,
    this.city,
    this.avatarUrl,
    required this.liters,
  });

  final int rank;
  final String name;
  final String orgType;
  final String? city;
  final String? avatarUrl;
  final double liters;

  factory LeaderRow.fromJson(Map<String, dynamic> j) => LeaderRow(
        rank: _i(j['rank']) ?? 0,
        name: j['name'] ?? '',
        orgType: j['org_type'] ?? 'other',
        city: j['city'],
        avatarUrl: j['avatar_url'],
        liters: _d(j['liters']) ?? 0,
      );
}

class Dashboard {
  Dashboard({
    required this.role,
    required this.name,
    this.city,
    required this.impact,
    required this.litersThisMonth,
    required this.moneyTotal,
    required this.moneyThisMonth,
    required this.openCount,
    required this.scheduledCount,
    required this.peersNearby,
    required this.myListings,
    required this.nearby,
    required this.recent,
    required this.rates,
  });

  final String role;
  final String name;
  final String? city;
  final Impact impact;
  final double litersThisMonth;
  final double moneyTotal;
  final double moneyThisMonth;
  final int openCount;
  final int scheduledCount;
  final int peersNearby;
  final List<OilListing> myListings;
  final List<OilListing> nearby;
  final List<Pickup> recent;
  final List<OilRate> rates;

  factory Dashboard.fromJson(Map<String, dynamic> j) => Dashboard(
        role: j['role'] ?? 'supplier',
        name: j['name'] ?? '',
        city: j['city'],
        impact: Impact.fromJson(j['impact'] ?? {}),
        litersThisMonth: _d(j['liters_this_month']) ?? 0,
        moneyTotal: _d(j['money_total']) ?? 0,
        moneyThisMonth: _d(j['money_this_month']) ?? 0,
        openCount: _i(j['open_count']) ?? 0,
        scheduledCount: _i(j['scheduled_count']) ?? 0,
        peersNearby: _i(j['peers_nearby']) ?? 0,
        myListings: ((j['my_listings'] as List?) ?? []).map((e) => OilListing.fromJson(e)).toList(),
        nearby: ((j['nearby'] as List?) ?? []).map((e) => OilListing.fromJson(e)).toList(),
        recent: ((j['recent'] as List?) ?? []).map((e) => Pickup.fromJson(e)).toList(),
        rates: ((j['rates'] as List?) ?? []).map((e) => OilRate.fromJson(e)).toList(),
      );
}

class GeoPlace {
  GeoPlace(this.label, this.lat, this.lng);
  final String label;
  final double lat;
  final double lng;

  factory GeoPlace.fromJson(Map<String, dynamic> j) =>
      GeoPlace(j['label'] ?? '', _d(j['lat']) ?? 0, _d(j['lng']) ?? 0);
}

class LatLng {
  const LatLng(this.lat, this.lng);
  final double lat;
  final double lng;
}

class MapPin {
  const MapPin({required this.lat, required this.lng, required this.label, this.id, this.highlight = false});
  final double lat;
  final double lng;
  final String label;
  final int? id;
  final bool highlight;
}

/// Distance in km between two points (same maths as the server).
double distanceKm(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371.0;
  final p1 = lat1 * math.pi / 180, p2 = lat2 * math.pi / 180;
  final dp = p2 - p1;
  final dl = (lng2 - lng1) * math.pi / 180;
  final a = math.sin(dp / 2) * math.sin(dp / 2) + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) * math.sin(dl / 2);
  return 2 * r * math.asin(math.sqrt(a));
}

class OperatorAccount {
  OperatorAccount({
    required this.id,
    required this.username,
    required this.name,
    this.createdAt,
  });

  final int id;
  final String username;
  final String name;
  final DateTime? createdAt;

  factory OperatorAccount.fromJson(Map<String, dynamic> j) => OperatorAccount(
        id: _i(j['id']) ?? 0,
        username: j['username'] ?? '',
        name: j['name'] ?? '',
        createdAt: _dt(j['created_at']),
      );
}

