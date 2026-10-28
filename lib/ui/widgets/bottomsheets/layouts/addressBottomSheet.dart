import 'package:e_demand/app/generalImports.dart';
import 'package:flutter/material.dart';

class AddressSheet extends StatefulWidget {
  const AddressSheet({
    required this.addressDataModel,
    final Key? key,
    this.addressId,
    this.isUpdateAddress,
  }) : super(key: key);
  final bool? isUpdateAddress;
  final String? addressId;
  final AddressModel addressDataModel;

  @override
  State<AddressSheet> createState() => _AddressSheetState();
}

class _AddressSheetState extends State<AddressSheet> {
  int locationTypeAddressIndex = 0;
  late AddressModel addressDataModel;
  Map<int, String> locationType = {0: "home", 1: "Office", 2: "Other"};
  bool isSetDefaultAddress = false;
  final GlobalKey<FormState> _addressFormKey = GlobalKey<FormState>();

  // Key to access CustomFieldsForm state for getValues()
  final GlobalKey<CustomFieldsFormState> _customFieldsFormKey =
      GlobalKey<CustomFieldsFormState>();

  late final TextEditingController mobileNumberFieldController =
      TextEditingController(text: addressDataModel.mobile);

  @override
  void initState() {
    super.initState();
    isSetDefaultAddress = widget.addressDataModel.isDefault?.toString() == '1';
    addressDataModel = widget.addressDataModel;
    locationTypeAddressIndex = widget.addressDataModel.type == "Office"
        ? 1
        : widget.addressDataModel.type == "Other"
        ? 2
        : 0;
  }

  @override
  void dispose() {
    mobileNumberFieldController.dispose();
    super.dispose();
  }

  @override
  Widget build(final BuildContext context) => CustomContainer(
    color: context.colors.backgroundPrimary,
    margin: EdgeInsetsDirectional.only(
      bottom: MediaQuery.viewPaddingOf(context).bottom,
    ),
    borderRadiusStyle: const BorderRadius.only(
      topLeft: Radius.circular(16),
      topRight: Radius.circular(16),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Column(
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 8,
                  decoration: BoxDecoration(
                    color: context.colors.borderDefault,
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
              ),
              const CustomSizedBox(height: 8),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: CustomText(
                  'manageAddress'.translate(context: context),
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: context.colors.textPrimary,
                ),
              ),
              const CustomSizedBox(height: 8),
              CustomContainer(
                height: 1.5,
                color: context.colors.backgroundSecondary,
              ),
            ],
          ),
        ),
        Flexible(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _addressFormKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // --- Address Type (Home / Office / Other) ---
                    StatefulBuilder(
                      builder: (final context, final setState) {
                        addressDataModel = addressDataModel.copyWith(
                          type: locationType[locationTypeAddressIndex],
                        );
                        return Row(
                          children: <Widget>[
                            FlatOutlinedButton(
                              icon: AppAssets.homeAdd,
                              isSelected: locationTypeAddressIndex == 0,
                              name: 'home'.translate(context: context),
                              onTap: () {
                                addressDataModel = addressDataModel.copyWith(
                                  type: 'Home',
                                );
                                locationTypeAddressIndex = 0;
                                setState(() {});
                              },
                            ),
                            const CustomSizedBox(width: 8),
                            FlatOutlinedButton(
                              icon: AppAssets.officeAdd,
                              isSelected: locationTypeAddressIndex == 1,
                              name: 'office'.translate(context: context),
                              onTap: () {
                                addressDataModel = addressDataModel.copyWith(
                                  type: 'Office',
                                );
                                locationTypeAddressIndex = 1;
                                setState(() {});
                              },
                            ),
                            const CustomSizedBox(width: 8),
                            FlatOutlinedButton(
                              icon: AppAssets.mapPinArea,
                              isSelected: locationTypeAddressIndex == 2,
                              name: 'other'.translate(context: context),
                              onTap: () {
                                addressDataModel = addressDataModel.copyWith(
                                  type: 'Other',
                                );
                                locationTypeAddressIndex = 2;
                                setState(() {});
                              },
                            ),
                          ],
                        );
                      },
                    ),

                    const CustomSizedBox(height: 16),

                    // --- Dynamic custom fields (replaces address + area) ---
                    BlocBuilder<GetCustomFieldsCubit, GetCustomFieldsState>(
                      builder: (context, state) {
                        if (state is GetCustomFieldsInProgress) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 20),
                            child: Center(
                              child: CustomCircularProgressIndicator(),
                            ),
                          );
                        } else if (state is GetCustomFieldsSuccess &&
                            state.fields.isNotEmpty) {
                          return CustomFieldsForm(
                            key: _customFieldsFormKey,
                            fields: state.fields,
                            initialValues: state.savedValues,
                          );
                        } else if (state is GetCustomFieldsFail) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 20),
                            child: ErrorContainer(
                              errorMessage: state.error,
                              showErrorImage: false,
                              errorMessageFontSize: 12,
                              onTapRetry: () {
                                context
                                    .read<GetCustomFieldsCubit>()
                                    .fetchCustomFields(
                                      addressId: widget.addressId,
                                    );
                              },
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),

                    // --- Mobile (always shown) ---
                    CustomTextFormField(
                      bottomPadding: 10,
                      validator: (number) => isValidMobileNumber(
                        number: number ?? '',
                        context: context,
                      ),
                      inputFormatters: UiUtils.allowOnlyDigits(),
                      controller: mobileNumberFieldController,
                      textInputType: TextInputType.number,
                      fillColor: context.colors.backgroundSecondary,
                      labelText: 'mobileNumber'.translate(context: context),
                      isRequired: true,
                      hintText: 'enterYourPhoneNumber'.translate(
                        context: context,
                      ),
                    ),

                    // --- Set as Default ---
                    Row(
                      children: [
                        StatefulBuilder(
                          builder: (final context, final setState) =>
                              CustomSizedBox(
                                height: 20,
                                width: 20,
                                child: Checkbox(
                                  activeColor: context.colors.backgroundBrand,
                                  fillColor: WidgetStateProperty.resolveWith(
                                    (states) =>
                                        states.contains(WidgetState.selected)
                                        ? context.colors.backgroundBrand
                                        : context.colors.backgroundPrimary,
                                  ),
                                  side: WidgetStateBorderSide.resolveWith(
                                    (states) => BorderSide(
                                      width: 1.0,
                                      color: context.colors.iconPrimary,
                                    ),
                                  ),
                                  shape: const CircleBorder(),
                                  visualDensity: VisualDensity.standard,
                                  checkColor: context.colors.textInverseLight,
                                  value: isSetDefaultAddress,
                                  onChanged: (final value) {
                                    isSetDefaultAddress = !isSetDefaultAddress;
                                    addressDataModel = addressDataModel
                                        .copyWith(
                                          isDefault: isSetDefaultAddress
                                              ? "1"
                                              : "0",
                                        );
                                    setState(() {});
                                  },
                                ),
                              ),
                        ),
                        const CustomSizedBox(width: 8),
                        Expanded(
                          child: CustomInkWellContainer(
                            onTap: () {
                              isSetDefaultAddress = !isSetDefaultAddress;
                              addressDataModel = addressDataModel.copyWith(
                                isDefault: isSetDefaultAddress ? "1" : "0",
                              );
                              setState(() {});
                            },
                            child: CustomText(
                              'setDefaultAddress'.translate(context: context),
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              color: context.colors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: context.colors.backgroundPrimary,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: BlocConsumer<AddAddressCubit, AddAddressState>(
                listener: (final context, final state) {
                  if (state is AddAddressSuccess) {
                    UiUtils.showMessage(
                      context,
                      widget.isUpdateAddress ?? false
                          ? 'addressUpdatedSuccessfully'.translate(
                              context: context,
                            )
                          : 'addressAddedSuccessfully'.translate(
                              context: context,
                            ),
                      ToastificationType.success,
                    );
                  } else if (state is AddAddressFail) {
                    UiUtils.showMessage(
                      context,
                      state.error.toString(),
                      ToastificationType.error,
                    );
                  }
                },
                builder: (final context, AddAddressState state) {
                  Widget? child;
                  if (state is AddAddressInProgress) {
                    child = CustomCircularProgressIndicator(
                      color: context.colors.textInverseLight,
                      widthAndHeight: 24,
                    );
                  }

                  void handleSave() {
                    if (state is AddAddressInProgress) return;
                    UiUtils.removeFocus();

                    if (_addressFormKey.currentState!.validate()) {
                      // Collect custom field values (if form is active)
                      final customValues = _customFieldsFormKey.currentState
                          ?.getValues();

                      addressDataModel = addressDataModel.copyWith(
                        mobile: mobileNumberFieldController.value.text.trim(),
                        customFieldValues: customValues,
                      );

                      if (widget.isUpdateAddress ?? false) {
                        final AddressModel model = addressDataModel.copyWith(
                          addressId: widget.addressId,
                        );
                        context.read<AddAddressCubit>().addAddress(model);
                      } else {
                        context.read<AddAddressCubit>().addAddress(
                          addressDataModel,
                        );
                      }
                    }
                  }

                  return Row(
                    children: [
                      Expanded(
                        child: CustomInkWellContainer(
                          borderRadius: BorderRadius.circular(
                            UiUtils.borderRadiusOf12,
                          ),
                          onTap: handleSave,
                          child: CustomContainer(
                            height: 48,
                            color: context.colors.backgroundBrand,
                            borderRadius: UiUtils.borderRadiusOf12,
                            child: Center(
                              child:
                                  child ??
                                  CustomText(
                                    'saveAddress'.translate(context: context),
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: context.colors.textInverseLight,
                                  ),
                            ),
                          ),
                        ),
                      ),
                      const CustomSizedBox(width: 12),
                      Expanded(
                        child: CustomInkWellContainer(
                          borderRadius: BorderRadius.circular(
                            UiUtils.borderRadiusOf12,
                          ),
                          onTap: () => Navigator.pop(context),
                          child: CustomContainer(
                            height: 48,
                            color: context.colors.backgroundBrandSubtle,
                            border: Border.all(
                              color: context.colors.borderBrand,
                            ),
                            borderRadius: UiUtils.borderRadiusOf12,
                            child: Center(
                              child: CustomText(
                                'close'.translate(context: context),
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: context.colors.textBrand,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
