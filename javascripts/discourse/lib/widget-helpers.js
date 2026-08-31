function itemsFromSetting(setting) {
  return new Set(setting.split("|").filter(Boolean));
}

function sortTags(tags) {
  const sortType = settings.sort_type;

  switch (sortType) {
    case "Count Ascending":
      return tags.sort((a, b) => a.count - b.count);
    case "Count Descending":
      return tags.sort((a, b) => b.count - a.count);
    case "Alphabetical Ascending":
      return tags.sort((a, b) => a.text.localeCompare(b.text));
    case "Alphabetical Descending":
      return tags.sort((a, b) => b.text.localeCompare(a.text));
    default:
      return tags.sort((a, b) => b.count - a.count);
  }
}

export { itemsFromSetting, sortTags };
