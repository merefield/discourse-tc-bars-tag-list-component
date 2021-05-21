import { ajax } from "discourse/lib/ajax";

export default {
  name: "layouts-tag-list",

  initialize(container) {
    const siteSettings = container.lookup("site-settings:main");
    let layouts;
    let layoutsError;

    // Import layouts plugin with safegaurd for when widget exists without plugin:
    try {
      layouts = requirejs(
        "discourse/plugins/discourse-layouts/discourse/lib/layouts"
      );
    } catch (error) {
      layoutsError = error;
      console.warn(layoutsError);
    }

    if (layoutsError || !siteSettings.calendar_enabled) return;

    ajax(`/tags.json`).then((tagList) => {
      const tags = tagList.tags;
      const tagGroups = tagList.extras.tag_groups;

      const props = {
        tags,
        siteSettings,
        tagGroups,
      };
      layouts.addSidebarProps(props);
    });
  },
};
