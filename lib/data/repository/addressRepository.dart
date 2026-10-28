// ignore_for_file: file_names

import 'package:dio/dio.dart';
import 'package:e_demand/app/generalImports.dart';

class AddressRepository {
  Future<Map<String, dynamic>> addAddress(
    final AddressModel addressDataModel,
  ) async {
    try {
      final Map<String, dynamic> parameters = addressDataModel.toMap();

      parameters[ApiParam.lattitude] = addressDataModel.latitude;

      // Convert file-type custom field values to MultipartFile for
      // multipart/form-data submission.
      if (addressDataModel.customFieldValues != null) {
        final customFields = addressDataModel.customFieldValues!;
        for (int i = 0; i < customFields.length; i++) {
          final field = customFields[i];
          final bool isFile = field['type']?.toString() == 'file';
          final String? filePath = field['value']?.toString();

          if (isFile && filePath != null && filePath.isNotEmpty) {
            parameters['custom_fields[$i][value]'] =
                await MultipartFile.fromFile(filePath);
          }
          // The non-file bracket-notation keys were already set by toMap().
        }
      }

      final response = await ApiClient.post(
        url: ApiUrl.addAddress,
        parameter: parameters,
        useAuthToken: true,
      );

      return response;
    } catch (e) {
      throw ApiException(e.toString());
    }
  }

  Future<Map<String, dynamic>> updateDefaultAddress(final String Id) async {
    try {
      final response = await ApiClient.post(
        url: ApiUrl.addAddress,
        parameter: {ApiParam.addressId: Id, ApiParam.isDefault: "1"},
        useAuthToken: true,
      );
      return response;
    } catch (e) {
      throw ApiException(e.toString());
    }
  }

  Future<List<GetAddressModel>> fetchAddress() async {
    try {
      final Map<String, dynamic> response = await ApiClient.post(
        url: ApiUrl.getAddress,
        parameter: {ApiParam.limit: 100, ApiParam.offset: 0},
        useAuthToken: true,
      );

      final List<GetAddressModel> mappedResponse =
          (response['data'] as List<dynamic>).map((final entry) {
            final getAddressModel = GetAddressModel.fromJson(entry);

            return getAddressModel;
          }).toList();

      return mappedResponse;
    } catch (e) {
      throw ApiException(e.toString());
    }
  }

  Future<Map<String, dynamic>> deleteAddress(final String id) async {
    final Map<String, dynamic> parameter = <String, dynamic>{
      ApiParam.addressId: id,
    };
    try {
      final Map<String, dynamic> response = await ApiClient.post(
        url: ApiUrl.deleteAddress,
        parameter: parameter,
        useAuthToken: true,
      );

      return response;
    } catch (e) {
      throw ApiException(e.toString());
    }
  }

  Future<CustomFieldsResponse> fetchCustomFields({String? addressId}) async {
    try {
      final Map<String, dynamic> parameter = {};
      if (addressId != null && addressId.isNotEmpty) {
        parameter[ApiParam.addressId] = addressId;
      }

      final Map<String, dynamic> response = await ApiClient.post(
        url: ApiUrl.getCustomFields,
        useAuthToken: true,
        parameter: parameter,
      );

      final data = response['data'] as Map<String, dynamic>? ?? {};

      // Parse saved values for the given address
      final Map<String, dynamic> savedValues = {};

      // Parse field definitions
      final List<CustomFieldModel>
      fields = (data['custom_fields'] as List<dynamic>? ?? []).map((entry) {
        final map = entry as Map<String, dynamic>;

        // Sometimes the backend API might inject the "value" directly into the field definition
        if (map.containsKey('value') && map['value'] != null) {
          final key = map['id']?.toString();
          if (key != null) savedValues[key] = map['value'];
        }
        return CustomFieldModel.fromJson(map);
      }).toList();

      // Sort by sort_order
      fields.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

      // Or they might be inside customer_address_custom_fields
      final savedList =
          data['customer_address_custom_fields'] as List<dynamic>? ?? [];
      for (final item in savedList) {
        if (item is Map<String, dynamic>) {
          final String? key =
              item['custom_field_id']?.toString() ?? item['id']?.toString();
          final value = item['value'];

          if (key != null && value != null) {
            savedValues[key] = value;
          }
        }
      }

      return CustomFieldsResponse(fields: fields, savedValues: savedValues);
    } catch (e) {
      throw ApiException(e.toString());
    }
  }
}
