// ============================================================
// utils/ghana_tax_presets.dart  –  Ghana Tax & Levy Reference Data
// ============================================================
// A reference list of the taxes, levies, and permit fees a
// Ghanaian micro/small enterprise is realistically likely to pay,
// used to let the owner tag a "Taxes & Levies" expense with WHICH
// specific one it is — instead of one undifferentiated bucket —
// so year-end reporting can actually break "Taxes & Levies" down
// into its real components (e.g. "Income Tax (MTS): GHS 1,200,
// Business Operating Permit: GHS 150").
//
// IMPORTANT — what this is and isn't: this is a categorization aid,
// not a tax calculator. JavisAudit does not compute or file anyone's
// taxes; it only helps label an expense the owner is ALREADY paying
// so their own records are more accurate. Rates shown are current
// as of the January 2026 VAT Act reform, but Ghanaian tax law and
// local Assembly fees change — the app should never be treated as
// the source of truth over GRA's own guidance or an accountant's
// advice, and this file deliberately doesn't hard-code exact GHS
// amounts for anything that isn't a fixed national percentage
// (Assembly permit fees vary by district and business category,
// so no single figure would be accurate for every user anyway).
// ============================================================

// The four broad groupings the business-type dropdown collapses
// into for the purpose of suggesting relevant tax/levy presets.
enum TaxCategoryGroup { foodService, retailSupermarket, services, other }

class TaxPreset {
  final String key;          // stable identifier — stored on the expense row
  final String label;        // shown in the dropdown
  final String note;         // one-line rate/description shown under the label
  const TaxPreset({required this.key, required this.label, required this.note});
}

class GhanaTaxPresets {
  // ── Applies to almost every micro/small business, any sector ──
  static const List<TaxPreset> common = [
    TaxPreset(
      key: 'mts_income_tax',
      label: 'Income Tax — Modified Taxation Scheme',
      note: 'Flat 3% of turnover — GRA\'s default for most informal-sector micro/small businesses.',
    ),
    TaxPreset(
      key: 'graduated_income_tax',
      label: 'Income Tax — Graduated (PIT)',
      note: '0%–35% bands — for sole proprietors above the Modified Taxation Scheme threshold.',
    ),
    TaxPreset(
      key: 'vat_paid_on_purchases',
      label: 'VAT / NHIL / GETFund (paid on purchases)',
      note: 'Unified 20% embedded in supplier prices — relevant even if you\'re not VAT-registered yourself.',
    ),
    TaxPreset(
      key: 'rent_withholding_tax',
      label: 'Rent Withholding Tax',
      note: '15% withheld on commercial/shop rent paid to a landlord.',
    ),
    TaxPreset(
      key: 'supplier_withholding_tax',
      label: 'Withholding Tax on Supplier Payments',
      note: '3% goods / 7.5% services / 5% works — on cumulative payments to one supplier over GHS 2,000/yr.',
    ),
    TaxPreset(
      key: 'ssnit_contribution',
      label: 'SSNIT Contributions',
      note: '13.5% employer + 5.5% employee — only if you have paid staff.',
    ),
    TaxPreset(
      key: 'business_operating_permit',
      label: 'Business Operating Permit',
      note: 'Annual fee set by your local Assembly (MMDA) — amount varies by district and business category.',
    ),
  ];

  // ── Food service (chop bar, restaurant, food joint) ──────────
  static const List<TaxPreset> foodService = [
    TaxPreset(
      key: 'fda_registration',
      label: 'FDA Registration Fee',
      note: 'Food and Drugs Authority — required for food handling/sale.',
    ),
    TaxPreset(
      key: 'food_hygiene_certificate',
      label: 'Food Hygiene Certificate',
      note: 'Local Assembly Environmental Health — plus food handler medical screening, renewed yearly.',
    ),
    TaxPreset(
      key: 'gta_license',
      label: 'Ghana Tourism Authority License',
      note: 'If classified as a restaurant/hospitality establishment.',
    ),
    TaxPreset(
      key: 'fire_safety_certificate',
      label: 'Fire Safety Certificate',
      note: 'Ghana National Fire Service — usually required for food premises.',
    ),
  ];

  // ── Retail / Supermarket ──────────────────────────────────────
  static const List<TaxPreset> retailSupermarket = [
    TaxPreset(
      key: 'fda_registration',
      label: 'FDA Registration Fee',
      note: 'Required if selling packaged food, drinks, cosmetics, or drugs.',
    ),
    TaxPreset(
      key: 'weights_measures_certification',
      label: 'Weights & Measures Certification',
      note: 'Ghana Standards Authority — for scales used at checkout.',
    ),
  ];

  // ── Services (consultants, salons, IT, transport, etc.) ──────
  static const List<TaxPreset> services = [
    TaxPreset(
      key: 'professional_license_fee',
      label: 'Professional / Trade License Fee',
      note: 'Sector-specific licensing body fee, where one applies to your profession.',
    ),
  ];

  // Maps one of BusinessProfile.businessTypes' 12 values to the
  // broad grouping used to decide which presets to surface first.
  static TaxCategoryGroup groupForBusinessType(String? businessType) {
    switch (businessType) {
      case 'Restaurant / Food Business':
        return TaxCategoryGroup.foodService;
      case 'Retail Shop':
      case 'Wholesale / Distribution':
        return TaxCategoryGroup.retailSupermarket;
      case 'Services Provider':
      case 'Technology / IT':
      case 'Healthcare':
      case 'Education':
      case 'Transport / Logistics':
      case 'Construction':
        return TaxCategoryGroup.services;
      default: // 'Manufacturing', 'Agriculture', 'Other', or unset
        return TaxCategoryGroup.other;
    }
  }

  // The sector-specific presets for a group — NOT including
  // `common`, since callers combine the two themselves (see
  // presetsForBusinessType) with the sector-specific ones surfaced
  // first in the dropdown.
  static List<TaxPreset> sectorPresetsFor(TaxCategoryGroup group) {
    switch (group) {
      case TaxCategoryGroup.foodService:
        return foodService;
      case TaxCategoryGroup.retailSupermarket:
        return retailSupermarket;
      case TaxCategoryGroup.services:
        return services;
      case TaxCategoryGroup.other:
        return const [];
    }
  }

  // The full preset list for a given (free-text) business type —
  // that type's own sector-specific presets first, then everything
  // in `common`. This is what the expense screen's dropdown uses:
  // the business's own likely taxes appear first, but every other
  // preset is still just a scroll away, since a single expense can
  // always be tagged differently from the business's usual profile
  // (e.g. a services business that also pays FDA fees for a
  // side product line).
  static List<TaxPreset> presetsForBusinessType(String? businessType) {
    final group = groupForBusinessType(businessType);
    return [...sectorPresetsFor(group), ...common];
  }

  // Every preset across every group, deduplicated by key — used
  // when there's no business type to prioritize against yet.
  static List<TaxPreset> get all {
    final seen = <String>{};
    final result = <TaxPreset>[];
    for (final preset in [...foodService, ...retailSupermarket, ...services, ...common]) {
      if (seen.add(preset.key)) result.add(preset);
    }
    return result;
  }

  static TaxPreset? byKey(String? key) {
    if (key == null) return null;
    for (final preset in all) {
      if (preset.key == key) return preset;
    }
    return null;
  }
}
