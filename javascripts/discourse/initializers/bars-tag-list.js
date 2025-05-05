export default {
  name: 'bars-tag-list',

  initialize(container) {
    const siteSettings = container.lookup('site-settings:main');

    if (!siteSettings.tagging_enabled) {
      console.warn(
        'To use this widget, please enable the site setting: tagging_enabled'
      );
    }
  }
};
