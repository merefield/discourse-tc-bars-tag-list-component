import { warn } from "@ember/debug";

export default {
  name: "bars-tag-list",

  initialize(container) {
    const siteSettings = container.lookup("service:site-settings");

    if (!siteSettings.tagging_enabled) {
      warn(
        "To use this widget, please enable the site setting: tagging_enabled",
        { id: "theme-component.bars-tag-list.tagging-enabled" }
      );
    }
  },
};
