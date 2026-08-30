class Country {
  final String? name;
  final String? flag;

  Country({
    required this.name,
    required this.flag,
  });

  factory Country.fromJson(Map<String, dynamic> json) {
    return Country(
      name: json['country'] as String,
      flag: json['flag'] as String,
    );
  }
}