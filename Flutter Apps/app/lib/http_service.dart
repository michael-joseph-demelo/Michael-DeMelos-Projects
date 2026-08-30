import 'dart:convert';
import 'package:http/http.dart' as http;
import 'country.dart';
import 'dart:math';

String generateDynamicInput(int length) {
  const characters = 'abcdefghijklmnopqrstuvwxyz';
  Random random = Random();

  String randomString = String.fromCharCodes(
    Iterable.generate(
      length,
          (_) => characters.codeUnitAt(
        random.nextInt(characters.length),
      ),
    ),
  );

  return randomString;
}

class HttpService {
  //final String countryURL = "https://cadatacatalog.state.gov/dataset/4a387c35-29cb-4902-b91d-3da0dc02e4b2/resource/299b3b67-3c09-46a3-9eb7-9d0086581bcb/download/countrytravelinfo.json";
  final String countryURL = "https://gist.githubusercontent.com/pratikbutani/20ded7151103bb30737e2ab1b336eb02/raw/be1391e25487ded4179b5f1c8eedb81b01226216/country-flag.json";

  Future<List<Country>> getRecommendations() async {
    final response = await http.get(Uri.parse(countryURL));
    String dynamicInput = generateDynamicInput(1);
    //print(dynamicInput);
    if (response.statusCode == 200) {
      List<dynamic> body = jsonDecode(response.body);

      List<Country> countries = body
          .map(
            (dynamic item) => Country.fromJson(item),
      )
          .where((country) =>
          country.name!.toLowerCase().contains(dynamicInput.toLowerCase()))
          .toList();
      //print(countries.length);
      return countries;
    } else {
      //print("Unable to retrieve recommendations.");
      throw "Unable to retrieve recommendations.";
    }
  }
}