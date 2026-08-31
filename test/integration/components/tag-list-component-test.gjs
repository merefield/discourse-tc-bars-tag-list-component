import { clearRender, click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import TagListComponent from "../../../discourse/components/tag-list-component";

function tag(id, text, count = id) {
  return { count, id, slug: text.toLowerCase().replaceAll(" ", "-"), text };
}

module("Integration | Component | TagListComponent", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.originalSettings = {
      defaultExpanded: settings.tag_groups_default_expanded,
      hiddenTagGroups: settings.hidden_tag_groups,
      hiddenTags: settings.hidden_tags,
      showCount: settings.show_count,
      sortType: settings.sort_type,
      tagCountLimit: settings.tag_count_limit,
    };
    this.originalTagsListedByGroup = this.siteSettings.tags_listed_by_group;

    settings.hidden_tag_groups = "";
    settings.hidden_tags = "";
    settings.show_count = false;
    settings.sort_type = "Alphabetical Ascending";
    settings.tag_count_limit = 2;
    settings.tag_groups_default_expanded = true;
    this.siteSettings.tags_listed_by_group = false;
    this.session.set("bars_tag_list_data", null);
    this.session.set("bars_tag_list_request", null);
  });

  hooks.afterEach(function () {
    settings.tag_groups_default_expanded =
      this.originalSettings.defaultExpanded;
    settings.hidden_tag_groups = this.originalSettings.hiddenTagGroups;
    settings.hidden_tags = this.originalSettings.hiddenTags;
    settings.show_count = this.originalSettings.showCount;
    settings.sort_type = this.originalSettings.sortType;
    settings.tag_count_limit = this.originalSettings.tagCountLimit;
    this.siteSettings.tags_listed_by_group = this.originalTagsListedByGroup;
  });

  test("deduplicates requests and progressively reveals ungrouped tags", async function (assert) {
    let requestCount = 0;
    settings.hidden_tags = "Hidden";

    pretender.get("/tags.json", () => {
      requestCount += 1;
      return response({
        extras: { categories: [] },
        tags: [
          tag(1, "Charlie"),
          tag(2, "Alpha"),
          tag(3, "Hidden"),
          tag(4, "Bravo"),
        ],
      });
    });

    await render(
      <template>
        <TagListComponent />
        <TagListComponent />
      </template>
    );

    assert.strictEqual(requestCount, 1, "the tag request is shared");
    assert.dom(".tag-list").exists({ count: 2 }, "both tag lists are rendered");
    assert
      .dom(".tag-list:first-child .bars-tag-link")
      .exists({ count: 2 }, "the configured initial tag limit is applied");
    assert
      .dom(".tag-list:first-child .bars-tag-link:first-child a")
      .hasAttribute("href", "/tag/alpha/2", "tags use native canonical links");

    await click(".tag-list:first-child .bars-tag-list__show-more .btn-link");

    assert
      .dom(".tag-list:first-child .bars-tag-link")
      .exists({ count: 3 }, "the next configured batch is revealed");
    assert
      .dom(".tag-list:first-child .bars-tag-list__show-more")
      .doesNotExist("Show more is removed after revealing every tag");
  });

  test("caches an empty tag response", async function (assert) {
    let requestCount = 0;

    pretender.get("/tags.json", () => {
      requestCount += 1;
      return response({ extras: { categories: [] }, tags: [] });
    });

    await render(<template><TagListComponent /></template>);
    assert.dom(".bars-tag-list__empty").exists("the empty state is rendered");

    await clearRender();
    await render(<template><TagListComponent /></template>);

    assert.strictEqual(requestCount, 1, "the empty response is reused");
  });

  test("limits expanded groups and renders ungrouped tags", async function (assert) {
    this.siteSettings.tags_listed_by_group = true;
    settings.hidden_tag_groups = "Hidden group";

    pretender.get("/tags.json", () =>
      response({
        extras: {
          tag_groups: [
            {
              id: 1,
              name: "Visible group",
              tags: [tag(1, "Charlie"), tag(2, "Alpha"), tag(3, "Bravo")],
            },
            {
              id: 2,
              name: "Hidden group",
              tags: [tag(4, "Delta")],
            },
          ],
        },
        tags: [tag(5, "Other tag")],
      })
    );

    await render(<template><TagListComponent /></template>);

    assert
      .dom(".bars-tag-group-toggler")
      .exists({ count: 1 }, "hidden tag groups are omitted");
    assert
      .dom(".bars-tag-group:first-child .bars-tag-link")
      .exists({ count: 2 }, "expanded groups respect the tag limit");
    assert
      .dom(".bars-tag-list__other-tags-title")
      .hasText("Other tags", "ungrouped tags have their own section");
    assert
      .dom(".bars-tag-group:last-child .bars-tag-link")
      .exists({ count: 1 }, "ungrouped tags are rendered");

    await click(
      ".bars-tag-group:first-child .bars-tag-list__show-more .btn-link"
    );

    assert
      .dom(".bars-tag-group:first-child .bars-tag-link")
      .exists({ count: 3 }, "Show more reveals the next group batch");
  });
});
