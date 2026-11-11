// AVTOMATIK YARATILGAN — qo'lda tahrirlamang.
// Manba: tool/gen_material_cyrillic.mjs (Flutter o'zbek tarjimasidan).
// ignore_for_file: public_member_api_docs

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'transliterate.dart';

/// `$nom` ko'rinishidagi o'rinbosarlarni buzmasdan o'giradi.
String _template(String raw) => raw.splitMapJoin(
      RegExp(r'\$\w+|\$\{\w+\}'),
      onMatch: (m) => m[0]!,
      onNonMatch: latinToCyrillic,
    );

/// Flutter'ning o'zbek tarjimasi — kirill yozuvida.
class MaterialLocalizationUzCyrl extends MaterialLocalizationUz {
  const MaterialLocalizationUzCyrl({
    required super.fullYearFormat,
    required super.compactDateFormat,
    required super.shortDateFormat,
    required super.mediumDateFormat,
    required super.longDateFormat,
    required super.yearMonthFormat,
    required super.shortMonthDayFormat,
    required super.decimalFormat,
    required super.twoDigitZeroPaddedFormat,
  });

  @override
  String get aboutListTileTitleRaw => _template(super.aboutListTileTitleRaw);

  @override
  String get alertDialogLabel => latinToCyrillic(super.alertDialogLabel);

  @override
  String get backButtonTooltip => latinToCyrillic(super.backButtonTooltip);

  @override
  String get bottomSheetLabel => latinToCyrillic(super.bottomSheetLabel);

  @override
  String get calendarModeButtonLabel => latinToCyrillic(super.calendarModeButtonLabel);

  @override
  String get cancelButtonLabel => latinToCyrillic(super.cancelButtonLabel);

  @override
  String get clearButtonTooltip => latinToCyrillic(super.clearButtonTooltip);

  @override
  String get closeButtonLabel => latinToCyrillic(super.closeButtonLabel);

  @override
  String get closeButtonTooltip => latinToCyrillic(super.closeButtonTooltip);

  @override
  String get collapsedHint => latinToCyrillic(super.collapsedHint);

  @override
  String get collapsedIconTapHint => latinToCyrillic(super.collapsedIconTapHint);

  @override
  String get continueButtonLabel => latinToCyrillic(super.continueButtonLabel);

  @override
  String get copyButtonLabel => latinToCyrillic(super.copyButtonLabel);

  @override
  String get currentDateLabel => latinToCyrillic(super.currentDateLabel);

  @override
  String get cutButtonLabel => latinToCyrillic(super.cutButtonLabel);

  @override
  String get dateInputLabel => latinToCyrillic(super.dateInputLabel);

  @override
  String get dateOutOfRangeLabel => latinToCyrillic(super.dateOutOfRangeLabel);

  @override
  String get datePickerHelpText => latinToCyrillic(super.datePickerHelpText);

  @override
  String get dateRangeEndDateSemanticLabelRaw => _template(super.dateRangeEndDateSemanticLabelRaw);

  @override
  String get dateRangeEndLabel => latinToCyrillic(super.dateRangeEndLabel);

  @override
  String get dateRangePickerHelpText => latinToCyrillic(super.dateRangePickerHelpText);

  @override
  String get dateRangeStartDateSemanticLabelRaw => _template(super.dateRangeStartDateSemanticLabelRaw);

  @override
  String get dateRangeStartLabel => latinToCyrillic(super.dateRangeStartLabel);

  @override
  String get dateSeparator => latinToCyrillic(super.dateSeparator);

  @override
  String get deleteButtonTooltip => latinToCyrillic(super.deleteButtonTooltip);

  @override
  String get dialModeButtonLabel => latinToCyrillic(super.dialModeButtonLabel);

  @override
  String get dialogLabel => latinToCyrillic(super.dialogLabel);

  @override
  String get drawerLabel => latinToCyrillic(super.drawerLabel);

  @override
  String get expandedHint => latinToCyrillic(super.expandedHint);

  @override
  String get expandedIconTapHint => latinToCyrillic(super.expandedIconTapHint);

  @override
  String get expansionTileCollapsedHint => latinToCyrillic(super.expansionTileCollapsedHint);

  @override
  String get expansionTileCollapsedTapHint => latinToCyrillic(super.expansionTileCollapsedTapHint);

  @override
  String get expansionTileExpandedHint => latinToCyrillic(super.expansionTileExpandedHint);

  @override
  String get expansionTileExpandedTapHint => latinToCyrillic(super.expansionTileExpandedTapHint);

  @override
  String get firstPageTooltip => latinToCyrillic(super.firstPageTooltip);

  @override
  String get hideAccountsLabel => latinToCyrillic(super.hideAccountsLabel);

  @override
  String get inputDateModeButtonLabel => latinToCyrillic(super.inputDateModeButtonLabel);

  @override
  String get inputTimeModeButtonLabel => latinToCyrillic(super.inputTimeModeButtonLabel);

  @override
  String get invalidDateFormatLabel => latinToCyrillic(super.invalidDateFormatLabel);

  @override
  String get invalidDateRangeLabel => latinToCyrillic(super.invalidDateRangeLabel);

  @override
  String get invalidTimeLabel => latinToCyrillic(super.invalidTimeLabel);

  @override
  String get lastPageTooltip => latinToCyrillic(super.lastPageTooltip);

  @override
  String? get licensesPackageDetailTextFew => super.licensesPackageDetailTextFew == null ? null : _template(super.licensesPackageDetailTextFew!);

  @override
  String? get licensesPackageDetailTextMany => super.licensesPackageDetailTextMany == null ? null : _template(super.licensesPackageDetailTextMany!);

  @override
  String? get licensesPackageDetailTextOne => super.licensesPackageDetailTextOne == null ? null : _template(super.licensesPackageDetailTextOne!);

  @override
  String get licensesPackageDetailTextOther => _template(super.licensesPackageDetailTextOther);

  @override
  String? get licensesPackageDetailTextTwo => super.licensesPackageDetailTextTwo == null ? null : _template(super.licensesPackageDetailTextTwo!);

  @override
  String? get licensesPackageDetailTextZero => super.licensesPackageDetailTextZero == null ? null : _template(super.licensesPackageDetailTextZero!);

  @override
  String get licensesPageTitle => latinToCyrillic(super.licensesPageTitle);

  @override
  String get lookUpButtonLabel => latinToCyrillic(super.lookUpButtonLabel);

  @override
  String get menuBarMenuLabel => latinToCyrillic(super.menuBarMenuLabel);

  @override
  String get menuDismissLabel => latinToCyrillic(super.menuDismissLabel);

  @override
  String get modalBarrierDismissLabel => latinToCyrillic(super.modalBarrierDismissLabel);

  @override
  String get moreButtonTooltip => latinToCyrillic(super.moreButtonTooltip);

  @override
  String get nextMonthTooltip => latinToCyrillic(super.nextMonthTooltip);

  @override
  String get nextPageTooltip => latinToCyrillic(super.nextPageTooltip);

  @override
  String get okButtonLabel => latinToCyrillic(super.okButtonLabel);

  @override
  String get openAppDrawerTooltip => latinToCyrillic(super.openAppDrawerTooltip);

  @override
  String get pageRowsInfoTitleRaw => _template(super.pageRowsInfoTitleRaw);

  @override
  String get pageRowsInfoTitleApproximateRaw => _template(super.pageRowsInfoTitleApproximateRaw);

  @override
  String get pasteButtonLabel => latinToCyrillic(super.pasteButtonLabel);

  @override
  String get popupMenuLabel => latinToCyrillic(super.popupMenuLabel);

  @override
  String get previousMonthTooltip => latinToCyrillic(super.previousMonthTooltip);

  @override
  String get previousPageTooltip => latinToCyrillic(super.previousPageTooltip);

  @override
  String get refreshIndicatorSemanticLabel => latinToCyrillic(super.refreshIndicatorSemanticLabel);

  @override
  String? get remainingTextFieldCharacterCountFew => super.remainingTextFieldCharacterCountFew == null ? null : _template(super.remainingTextFieldCharacterCountFew!);

  @override
  String? get remainingTextFieldCharacterCountMany => super.remainingTextFieldCharacterCountMany == null ? null : _template(super.remainingTextFieldCharacterCountMany!);

  @override
  String? get remainingTextFieldCharacterCountOne => super.remainingTextFieldCharacterCountOne == null ? null : _template(super.remainingTextFieldCharacterCountOne!);

  @override
  String get remainingTextFieldCharacterCountOther => _template(super.remainingTextFieldCharacterCountOther);

  @override
  String? get remainingTextFieldCharacterCountTwo => super.remainingTextFieldCharacterCountTwo == null ? null : _template(super.remainingTextFieldCharacterCountTwo!);

  @override
  String? get remainingTextFieldCharacterCountZero => super.remainingTextFieldCharacterCountZero == null ? null : _template(super.remainingTextFieldCharacterCountZero!);

  @override
  String get reorderItemDown => latinToCyrillic(super.reorderItemDown);

  @override
  String get reorderItemLeft => latinToCyrillic(super.reorderItemLeft);

  @override
  String get reorderItemRight => latinToCyrillic(super.reorderItemRight);

  @override
  String get reorderItemToEnd => latinToCyrillic(super.reorderItemToEnd);

  @override
  String get reorderItemToStart => latinToCyrillic(super.reorderItemToStart);

  @override
  String get reorderItemUp => latinToCyrillic(super.reorderItemUp);

  @override
  String get rowsPerPageTitle => latinToCyrillic(super.rowsPerPageTitle);

  @override
  String get saveButtonLabel => latinToCyrillic(super.saveButtonLabel);

  @override
  String get scanTextButtonLabel => latinToCyrillic(super.scanTextButtonLabel);

  @override
  String get scrimLabel => latinToCyrillic(super.scrimLabel);

  @override
  String get scrimOnTapHintRaw => _template(super.scrimOnTapHintRaw);

  @override
  String get searchFieldLabel => latinToCyrillic(super.searchFieldLabel);

  @override
  String get searchWebButtonLabel => latinToCyrillic(super.searchWebButtonLabel);

  @override
  String get selectAllButtonLabel => latinToCyrillic(super.selectAllButtonLabel);

  @override
  String get selectYearSemanticsLabel => latinToCyrillic(super.selectYearSemanticsLabel);

  @override
  String get selectedDateLabel => latinToCyrillic(super.selectedDateLabel);

  @override
  String? get selectedRowCountTitleFew => super.selectedRowCountTitleFew == null ? null : _template(super.selectedRowCountTitleFew!);

  @override
  String? get selectedRowCountTitleMany => super.selectedRowCountTitleMany == null ? null : _template(super.selectedRowCountTitleMany!);

  @override
  String? get selectedRowCountTitleOne => super.selectedRowCountTitleOne == null ? null : _template(super.selectedRowCountTitleOne!);

  @override
  String get selectedRowCountTitleOther => _template(super.selectedRowCountTitleOther);

  @override
  String? get selectedRowCountTitleTwo => super.selectedRowCountTitleTwo == null ? null : _template(super.selectedRowCountTitleTwo!);

  @override
  String? get selectedRowCountTitleZero => super.selectedRowCountTitleZero == null ? null : _template(super.selectedRowCountTitleZero!);

  @override
  String get shareButtonLabel => latinToCyrillic(super.shareButtonLabel);

  @override
  String get showAccountsLabel => latinToCyrillic(super.showAccountsLabel);

  @override
  String get showMenuTooltip => latinToCyrillic(super.showMenuTooltip);

  @override
  String get signedInLabel => latinToCyrillic(super.signedInLabel);

  @override
  String get tabLabelRaw => _template(super.tabLabelRaw);

  @override
  String get timePickerDialHelpText => latinToCyrillic(super.timePickerDialHelpText);

  @override
  String get timePickerHourLabel => latinToCyrillic(super.timePickerHourLabel);

  @override
  String get timePickerHourModeAnnouncement => latinToCyrillic(super.timePickerHourModeAnnouncement);

  @override
  String get timePickerInputHelpText => latinToCyrillic(super.timePickerInputHelpText);

  @override
  String get timePickerMinuteLabel => latinToCyrillic(super.timePickerMinuteLabel);

  @override
  String get timePickerMinuteModeAnnouncement => latinToCyrillic(super.timePickerMinuteModeAnnouncement);

  @override
  String get unspecifiedDate => latinToCyrillic(super.unspecifiedDate);

  @override
  String get unspecifiedDateRange => latinToCyrillic(super.unspecifiedDateRange);

  @override
  String get viewLicensesButtonLabel => latinToCyrillic(super.viewLicensesButtonLabel);

  @override
  String formatMonthYear(DateTime date) => latinToCyrillic(super.formatMonthYear(date));

  @override
  String formatMediumDate(DateTime date) => latinToCyrillic(super.formatMediumDate(date));

  @override
  String formatFullDate(DateTime date) => latinToCyrillic(super.formatFullDate(date));

  @override
  String formatShortDate(DateTime date) => latinToCyrillic(super.formatShortDate(date));

  @override
  String formatShortMonthDay(DateTime date) => latinToCyrillic(super.formatShortMonthDay(date));

  @override
  List<String> get narrowWeekdays => super.narrowWeekdays.map(latinToCyrillic).toList();
}

/// Material matnlari kirillda — faqat kirill yozuvi tanlanganda ulanadi.
class UzCyrillicMaterialDelegate extends LocalizationsDelegate<MaterialLocalizations> {
  const UzCyrillicMaterialDelegate();

  @override
  bool isSupported(Locale locale) => locale.languageCode == 'uz';

  @override
  Future<MaterialLocalizations> load(Locale locale) {
    const name = 'uz';
    return SynchronousFuture<MaterialLocalizations>(MaterialLocalizationUzCyrl(
      fullYearFormat: intl.DateFormat.y(name),
      compactDateFormat: intl.DateFormat('dd.MM.yyyy', name),
      shortDateFormat: intl.DateFormat.yMMMd(name),
      mediumDateFormat: intl.DateFormat.MMMEd(name),
      longDateFormat: intl.DateFormat.yMMMMEEEEd(name),
      yearMonthFormat: intl.DateFormat.yMMMM(name),
      shortMonthDayFormat: intl.DateFormat.MMMd(name),
      decimalFormat: intl.NumberFormat.decimalPattern(name),
      twoDigitZeroPaddedFormat: intl.NumberFormat('00', name),
    ));
  }

  @override
  bool shouldReload(UzCyrillicMaterialDelegate old) => false;
}
