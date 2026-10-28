class GetAddressModel {
  String? id;
  String? type;
  String? address;
  String? mobile;
  String? lattitude;
  String? longitude;
  String? isDefault;

  /// Map of custom field id -> raw value (String) as saved on the server.
  Map<String, dynamic>? customFieldValues;

  GetAddressModel({
    this.id,
    this.type,
    this.address,
    this.mobile,
    this.lattitude,
    this.longitude,
    this.isDefault,
    this.customFieldValues,
  });

  GetAddressModel.fromJson(final Map<String, dynamic> json) {
    id = json['id']?.toString() ?? '0';
    type = json['type']?.toString() ?? '';
    address = json['address']?.toString() ?? '';
    mobile = json['mobile']?.toString() ?? '';
    lattitude = json['lattitude']?.toString() ?? '';
    longitude = json['longitude']?.toString() ?? '';
    isDefault = json['is_default']?.toString() ?? '';
    final rawCustomFields = json['custom_fields'];
    if (rawCustomFields is Map) {
      customFieldValues = Map<String, dynamic>.from(rawCustomFields);
    }
  }

  GetAddressModel copyWith({
    String? id,
    String? type,
    String? address,
    String? mobile,
    String? lattitude,
    String? longitude,
    String? isDefault,
    Map<String, dynamic>? customFieldValues,
  }) {
    return GetAddressModel(
      id: id ?? this.id,
      type: type ?? this.type,
      address: address ?? this.address,
      mobile: mobile ?? this.mobile,
      lattitude: lattitude ?? this.lattitude,
      longitude: longitude ?? this.longitude,
      isDefault: isDefault ?? this.isDefault,
      customFieldValues: customFieldValues ?? this.customFieldValues,
    );
  }
}
