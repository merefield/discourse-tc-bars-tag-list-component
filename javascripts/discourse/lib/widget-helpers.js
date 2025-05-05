function isHidden(item, setting) {
  const hiddenItem = setting.split('|');

  if (hiddenItem.includes(item)) {
    return true;
  }
}

function sortTags(tags) {
  const sortType = settings.sort_type;

  switch (sortType) {
    case 'Count Ascending':
      return tags.sort((a, b) => (a.count > b.count ? 1 : -1));
      break;
    case 'Count Descending':
      return tags.sort((a, b) => (b.count > a.count ? 1 : -1));
      break;
    case 'Alphabetical Ascending':
      return tags.sort((a, b) => (a.text > b.text ? 1 : -1));
      break;
    case 'Alphabetical Descending':
      return tags.sort((a, b) => (b.text > a.text ? 1 : -1));
      break;
    default:
      return tags.sort((a, b) => (b.count > a.count ? 1 : -1));
  }
}

export { isHidden, sortTags };
