import Component from '@glimmer/component';
import { getOwner } from '@ember/application';
import { action } from '@ember/object';
import { tracked } from '@glimmer/tracking';
import DiscourseURL from "discourse/lib/url";
import { ajax } from 'discourse/lib/ajax';
import { i18n } from "discourse-i18n";
import { service } from "@ember/service";
import { fn } from "@ember/helper";
import { popupAjaxError } from "discourse/lib/ajax-error";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import DButton from "discourse/components/d-button";
import icon from "discourse/helpers/d-icon";
import TagChooser from "select-kit/components/tag-chooser";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import { isHidden, sortTags } from '../lib/widget-helpers';


export default class TagListComponent extends Component {
  @service siteSettings;
  @service session;
  @tracked tags = this.session.get("bars_tag_list_tags")
  @tracked tagGroups = this.session.get("bars_tag_list_tag_groups");
  @tracked loading = false;
  
  get showCount() {
    return this.settings.show
  }

  @action
  getTags() {
    debugger;
    this.tags = this.session.get("bars_tag_list_tags")
    this.tagGroups = this.session.get("bars_tag_list_tag_groups");
    if (this.tags?.length > 0 && this.tagGroups?.length > 0) {
      return;
    }

    this.loading = true;

    ajax(`/tags.json`).then((tagList) => {
      // If site is using Tag Groups:
      let rawTagGroups;
      let tagGroups;

      if (this.siteSettings.tags_listed_by_group) {
        rawTagGroups = tagList.extras.tag_groups;
        rawTagGroups = rawTagGroups.map((rawGroup) => (
          { ...rawGroup, hidden: !settings.tag_groups_default_expanded }
        ));
        tagGroups = rawTagGroups.filter((tagGroup) => {
          tagGroup['tags'] = tagGroup.tags.filter((tag) => {
            return !isHidden(tag.text, settings.hidden_tags);
          });
          sortTags(tagGroup.tags);
          return !isHidden(tagGroup.name, settings.hidden_tag_groups);
        });
      } else {
        rawTagGroups = null;
        tagGroups = null;
      }

      // If site is not using Tag Groups:
      const rawTags = tagList.tags;
      const tags = rawTags.filter((tag) => {
        return !isHidden(tag.text, settings.hidden_tags);
      });

      sortTags(tags);
      this.loading = false;
      this.tags = tags;
      this.tagGroups = tagGroups;
      const session = getOwner(this).lookup("session:main");
      this.session.set("bars_tag_list_tags", tags);
      this.session.set("bars_tag_list_tag_groups", tagGroups);
    }).catch((error) => {
      this.loading = false;
      popupAjaxError(error);
    });
  }

  @action
  onTagClick(tag) {
    DiscourseURL.routeTo(`/tag/${tag.id}`);
  }

  @action
  onGroupButtonClick(group) {
    this.tagGroups = this.tagGroups.map((tagGroup) => {
      if (group.name === tagGroup.name) {
        return { ...tagGroup, hidden: !tagGroup.hidden }; // create new object
      }
      return tagGroup;
    });
  }

  <template>
    <div {{didInsert this.getTags}} class="tag-list">
      <div class="tag-list-header">
        <a href="/tags" class="bars-tag-list-header">{{i18n (themePrefix "header_title")}}</a>
      </div>
      {{#unless this.tags.length}}
        <a>{{i18n (themePrefix "no_tags")}}</a>
      {{else}}
        <ConditionalLoadingSpinner @condition={{this.loading}} />
        <ul class="bars-tag-items">
          {{#if this.tagGroups}}
            {{#each this.tagGroups as |tagGroup|}}
              <ul class="bars-tag-group">
                <DButton class="bars-tag-group-toggler btn-transparent" @action={{fn this.onGroupButtonClick tagGroup}}>
                  {{#if tagGroup.hidden}}
                    {{icon "caret-right"}}
                  {{else}}
                    {{icon "caret-down"}}
                  {{/if}}
                  {{tagGroup.name}}
                </DButton>
                {{! Tag Group Contents }}
                {{#unless tagGroup.hidden}}
                  <div class="bars-tag-group-contents">
                    {{#each tagGroup.tags as |tag|}}
                      <li class="bars-tag-link" data-tag-name="{{tag.text}}" onClick={{action this.onTagClick tag}}>
                        <span class="discourse-tag {{this.siteSettings.tag_style}}">{{tag.text}}</span>
                        {{#if settings.show_count}}
                          <span class="tag-count">x {{tag.count}}</span>
                        {{/if}}
                      </li>
                    {{/each}}
                  </div>
                {{/unless}}
              </ul>
            {{/each}}
          {{/if}}
        </ul>
      {{/unless}}
    </div>
  </template>
}
