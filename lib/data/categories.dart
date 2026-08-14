/// Central place for the task category → sub-category tree.
///
/// Used by:
///  - CreateRequestScreen (Category / Sub-category dropdowns when posting a task)
///  - BuyerHomeScreen & SellerHomeScreen (category chip bar + sub-category chip bar)
///  - HomeProvider (filtering logic)
///
/// Keeping this in one file means adding/renaming a category or sub-category
/// only has to happen in one place.
library task_categories;

/// Ordered list of top-level categories shown in the main chip bar.
/// "All" is handled separately by the screens/provider (it means "no filter").
const List<String> mainCategories = [
  'Design',
  'Development',
  'Writing',
  'Video',
  'Marketing',
];

/// Sub-categories for each main category, in display order.
const Map<String, List<String>> subCategories = {
  'Design': [
    'UI/UX Design',
    'Graphic Design',
    'Logo Design',
    'Illustration',
    'Web Design',
  ],
  'Development': [
    'Web Development',
    'Mobile Development',
    'Backend Development',
    'Full Stack Development',
    'Game Development',
  ],
  'Writing': [
    'Content Writing',
    'Copywriting',
    'Translation',
    'Technical Writing',
    'Proofreading & Editing',
  ],
  'Video': [
    'Video Editing',
    'Animation',
    'Motion Graphics',
    'Video Production',
  ],
  'Marketing': [
    'Social Media Marketing',
    'SEO',
    'Advertising',
    'Email Marketing',
    'Content Marketing',
  ],
};

/// Convenience helper — returns the sub-categories for [category],
/// or an empty list if it has none (e.g. unknown category or "All").
List<String> subCategoriesFor(String category) =>
    subCategories[category] ?? const [];
