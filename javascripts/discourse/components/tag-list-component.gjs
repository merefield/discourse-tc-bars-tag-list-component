import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import getURL from "discourse/lib/get-url";
import DButton from "discourse/ui-kit/d-button";
import DConditionalLoadingSpinner from "discourse/ui-kit/d-conditional-loading-spinner";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import { i18n } from "discourse-i18n";
import { itemsFromSetting, sortTags } from "../lib/widget-helpers";

const CACHE_KEY = "bars_tag_list_data";
const REQUEST_KEY = "bars_tag_list_request";
const DEFAULT_TAG_COUNT_LIMIT = 20;

function tagCountLimit() {
  return Math.max(
    Number(settings.tag_count_limit) || DEFAULT_TAG_COUNT_LIMIT,
    1
  );
}

function prepareTags(tags, hiddenTags) {
  const visibleTags = (tags || [])
    .filter((tag) => !hiddenTags.has(tag.text))
    .map((tag) => ({
      count: tag.count,
      id: tag.id,
      text: tag.text,
      url: getURL(`/tag/${tag.slug || `${tag.id}-tag`}/${tag.id}`),
    }));

  return sortTags(visibleTags);
}

class TagItems extends Component {
  @tracked visibleCount = tagCountLimit();

  get visibleTags() {
    return this.args.tags.slice(0, this.visibleCount);
  }

  get hasMoreTags() {
    return this.visibleCount < this.args.tags.length;
  }

  @action
  showMore() {
    this.visibleCount += tagCountLimit();
  }

  <template>
    <ul class="bars-tag-contents" aria-label={{@label}} ...attributes>
      {{#each this.visibleTags as |tag|}}
        <li class="bars-tag-link" data-tag-name={{tag.text}}>
          <a href={{tag.url}} class={{dConcatClass "discourse-tag" @tagStyle}}>
            {{tag.text}}
            {{#if @showCount}}
              <span class="tag-count">x {{tag.count}}</span>
            {{/if}}
          </a>
        </li>
      {{/each}}
      {{#if this.hasMoreTags}}
        <li class="bars-tag-list__show-more">
          <DButton
            @action={{this.showMore}}
            @display="link"
            @translatedLabel={{i18n (themePrefix "show_more")}}
          />
        </li>
      {{/if}}
    </ul>
  </template>
}

export default class TagListComponent extends Component {
  @service siteSettings;
  @service session;

  @tracked tags = [];
  @tracked tagGroups = null;
  @tracked loading = true;

  constructor() {
    super(...arguments);

    const cachedData = this.session.get(CACHE_KEY);
    if (this.cacheIsValid(cachedData)) {
      this.applyTagData(cachedData);
    }
  }

  get cacheSignature() {
    return JSON.stringify([
      this.siteSettings.tags_listed_by_group,
      settings.hidden_tags,
      settings.hidden_tag_groups,
      settings.sort_type,
    ]);
  }

  get grouped() {
    return this.tagGroups !== null;
  }

  get hasTags() {
    return (
      this.tags.length > 0 ||
      this.tagGroups?.some((tagGroup) => tagGroup.tags.length > 0)
    );
  }

  cacheIsValid(cachedData) {
    return cachedData?.loaded && cachedData.signature === this.cacheSignature;
  }

  applyTagData(data) {
    this.tags = data.tags;
    this.tagGroups =
      data.tagGroups?.map((tagGroup) => ({
        ...tagGroup,
        hidden: !settings.tag_groups_default_expanded,
      })) ?? null;
    this.loading = false;
  }

  prepareTagData(tagList, signature = this.cacheSignature) {
    const hiddenTags = itemsFromSetting(settings.hidden_tags);
    const hiddenTagGroups = itemsFromSetting(settings.hidden_tag_groups);
    const tags = prepareTags(tagList.tags, hiddenTags);
    let tagGroups = null;

    if (this.siteSettings.tags_listed_by_group) {
      tagGroups = (tagList.extras?.tag_groups || [])
        .filter((tagGroup) => !hiddenTagGroups.has(tagGroup.name))
        .map((tagGroup) => ({
          ...tagGroup,
          tags: prepareTags(tagGroup.tags, hiddenTags),
        }))
        .filter((tagGroup) => tagGroup.tags.length > 0);
    }

    return {
      loaded: true,
      signature,
      tagGroups,
      tags,
    };
  }

  loadTagData() {
    const pendingRequest = this.session.get(REQUEST_KEY);
    if (pendingRequest?.signature === this.cacheSignature) {
      return pendingRequest.promise;
    }

    const signature = this.cacheSignature;
    const request = { signature };
    request.promise = ajax("/tags.json")
      .then((tagList) => {
        const data = this.prepareTagData(tagList, signature);
        this.session.set(CACHE_KEY, data);
        return data;
      })
      .finally(() => {
        const currentRequest = this.session.get(REQUEST_KEY);
        if (currentRequest === request) {
          this.session.set(REQUEST_KEY, null);
        }
      });

    this.session.set(REQUEST_KEY, request);
    return request.promise;
  }

  @action
  async getTags() {
    const cachedData = this.session.get(CACHE_KEY);
    if (this.cacheIsValid(cachedData)) {
      return;
    }

    this.loading = true;

    try {
      this.applyTagData(await this.loadTagData());
    } catch (error) {
      this.loading = false;
      popupAjaxError(error);
    }
  }

  @action
  onGroupButtonClick(group) {
    this.tagGroups = this.tagGroups.map((tagGroup) => {
      if (group.id === tagGroup.id) {
        return { ...tagGroup, hidden: !tagGroup.hidden };
      }
      return tagGroup;
    });
  }

  <template>
    <div {{didInsert this.getTags}} class="tag-list" ...attributes>
      <div class="tag-list-header">
        <a href="/tags" class="bars-tag-list-header">
          {{i18n (themePrefix "header_title")}}
        </a>
      </div>

      <DConditionalLoadingSpinner @condition={{this.loading}}>
        {{#if this.hasTags}}
          {{#if this.grouped}}
            <ul class="bars-tag-items">
              {{#each this.tagGroups as |tagGroup|}}
                <li class="bars-tag-group">
                  <DButton
                    class="bars-tag-group-toggler btn-transparent"
                    @action={{fn this.onGroupButtonClick tagGroup}}
                    @icon={{if tagGroup.hidden "caret-right" "caret-down"}}
                    @translatedLabel={{tagGroup.name}}
                  />
                  {{#unless tagGroup.hidden}}
                    <TagItems
                      @label={{tagGroup.name}}
                      @showCount={{settings.show_count}}
                      @tags={{tagGroup.tags}}
                      @tagStyle={{this.siteSettings.tag_style}}
                      class="bars-tag-group-contents"
                    />
                  {{/unless}}
                </li>
              {{/each}}

              {{#if this.tags.length}}
                <li class="bars-tag-group">
                  <div class="bars-tag-list__other-tags-title">
                    {{i18n (themePrefix "other_tags")}}
                  </div>
                  <TagItems
                    @label={{i18n (themePrefix "other_tags")}}
                    @showCount={{settings.show_count}}
                    @tags={{this.tags}}
                    @tagStyle={{this.siteSettings.tag_style}}
                    class="bars-tag-group-contents"
                  />
                </li>
              {{/if}}
            </ul>
          {{else}}
            <TagItems
              @label={{i18n (themePrefix "header_title")}}
              @showCount={{settings.show_count}}
              @tags={{this.tags}}
              @tagStyle={{this.siteSettings.tag_style}}
              class="bars-tag-items"
            />
          {{/if}}
        {{else}}
          <span class="bars-tag-list__empty">
            {{i18n (themePrefix "no_tags")}}
          </span>
        {{/if}}
      </DConditionalLoadingSpinner>
    </div>
  </template>
}
