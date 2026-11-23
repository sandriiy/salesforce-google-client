import { LightningElement, api } from 'lwc';

import {
    SEARCH_FILTERS,
    DATE_PRESET,
    EMPTY_SEARCH_CRITERIA,
    normalizeSearchCriteria,
    isSearchFilterSet,
    hasSearchCriteria,
    describeSearchFilter,
    pickSearchFilterOption,
    setSearchDayRange,
    searchDayRangeOf,
    buildOwnerOptions,
    clearSearchFilter
} from 'c/googleCloudFileSearchUtils';
import retrieveFileExplorerOwners from '@salesforce/apex/GoogleCloudFilesController.retrieveFileExplorerOwners';
import USER_ID from '@salesforce/user/Id';

const KEY_PHRASES_PLACEHOLDER = 'Search by words from the name, AI summary or labels, or "an exact phrase"';
const CHIP_BUTTON_CLASS = 'gc-search-chip__main';
const MENU_ITEM_CLASS = 'gc-search-chip__option';
const MENU_CLASS = 'gc-search-chip__menu';
const MENU_CLASSES = `slds-dropdown slds-dropdown_left ${MENU_CLASS}`;
const SCROLLING_MENU_CLASSES = `${MENU_CLASSES} slds-dropdown_length-10`;
const CHIP_ROW_CLASS = 'gc-search-filters__chips';
const KEY = {
    ESCAPE: 'Escape',
    ARROW_DOWN: 'ArrowDown',
    ARROW_UP: 'ArrowUp',
    HOME: 'Home',
    END: 'End',
    SPACE: ' '
};

export default class GoogleCloudFileSearchFilters extends LightningElement {
    @api criteria;

    openFilterKey = null;
    pendingMenuFocusKey = null;
    isPendingMenuFocusOnItem = false;
    pendingChipFocusKey = null;

    owners = [];
    hasLoadedOwners = false;
    isLoadingOwners = false;

    keyPhrasesPlaceholder = KEY_PHRASES_PLACEHOLDER;

    renderedCallback() {
        this.fitOpenMenu();

        if (this.pendingMenuFocusKey) {
            const filterKey = this.pendingMenuFocusKey;
            this.pendingMenuFocusKey = null;

            if (this.isPendingMenuFocusOnItem) this.focusMenuItem(filterKey);
            else this.focusMenu();
        }

        if (this.pendingChipFocusKey) {
            const filterKey = this.pendingChipFocusKey;
            this.pendingChipFocusKey = null;
            this.focusChip(filterKey);
        }
    }

    get currentCriteria() {
        return normalizeSearchCriteria(this.criteria);
    }

    get keyPhrases() {
        return this.currentCriteria.keyPhrases;
    }

    get hasCriteria() {
        return hasSearchCriteria(this.currentCriteria);
    }

    get chips() {
        const criteria = this.currentCriteria;

        return SEARCH_FILTERS.map((filter) => {
            const isSet = isSearchFilterSet(filter, criteria);
            const isOpen = this.openFilterKey === filter.key;
            const chosenValues = filter.isMultiple ? criteria[filter.key] : [criteria[filter.key]];
            const dayRange = searchDayRangeOf(criteria, filter.key);
            const filterOptions = filter.listsOwners ? buildOwnerOptions(this.owners, USER_ID) : filter.options;

            return {
                key: filter.key,
                name: filter.label,
                label: describeSearchFilter(filter, criteria),
                isSet,
                isOpen,
                chipClass: isSet ? 'gc-search-chip gc-search-chip_set' : 'gc-search-chip',
                expandedText: isOpen ? 'true' : 'false',
                removeLabel: `Remove the ${filter.label} filter`,
                itemRole: filter.isMultiple ? 'menuitemcheckbox' : 'menuitemradio',
                menuClass: filter.listsOwners ? SCROLLING_MENU_CLASSES : MENU_CLASSES,
                isLoadingOptions: filter.listsOwners === true && this.isLoadingOwners,
                showRange: filter.isDateRange === true && criteria[filter.key] === DATE_PRESET.CUSTOM,
                fromDay: dayRange.from,
                toDay: dayRange.to,
                options: filterOptions.map((option) => {
                    const isChecked = chosenValues.includes(option.value);

                    return {
                        value: option.value,
                        label: option.label,
                        isChecked,
                        checkedText: isChecked ? 'true' : 'false'
                    };
                })
            };
        });
    }

    handleKeyPhrasesChange(event) {
        this.dispatchCriteria({ ...this.currentCriteria, keyPhrases: event.target.value || '' });
    }

    handleChipToggle(event) {
        const filterKey = event.currentTarget.dataset.key;

        if (this.openFilterKey === filterKey) {
            this.openFilterKey = null;
            return;
        }

        this.openMenu(filterKey, this.isKeyboardClick(event));
    }

    handleChipRemove(event) {
        const filterKey = event.currentTarget.dataset.key;

        this.openFilterKey = null;
        this.pendingChipFocusKey = filterKey;
        this.dispatchCriteria(clearSearchFilter(this.currentCriteria, filterKey));
    }

    handleOptionPick(event) {
        event.preventDefault();

        const { key, value, label } = event.currentTarget.dataset;
        this.pickOption(key, value, label);
    }

    handleChipKeyDown(event) {
        const filterKey = event.currentTarget.dataset.key;
        const isMenuItem = event.target.classList?.contains(MENU_ITEM_CLASS) === true;
        const isMenu = event.target.classList?.contains(MENU_CLASS) === true;
        const isChipButton = event.target.classList?.contains(CHIP_BUTTON_CLASS) === true;

        if (event.key === KEY.ESCAPE && this.openFilterKey === filterKey) {
            event.preventDefault();
            event.stopPropagation();
            this.closeMenu(filterKey);
            return;
        }

        if (event.key === KEY.ARROW_DOWN && isChipButton) {
            event.preventDefault();
            this.openMenu(filterKey, true);
            return;
        }

        if (!isMenuItem && !isMenu) return;

        if (event.key === KEY.SPACE && isMenuItem) {
            event.preventDefault();
            this.pickOption(filterKey, event.target.dataset.value, event.target.dataset.label);
            return;
        }

        if ([KEY.ARROW_DOWN, KEY.ARROW_UP, KEY.HOME, KEY.END].includes(event.key)) {
            event.preventDefault();
            this.moveMenuFocus(filterKey, isMenuItem ? event.target : null, event.key);
        }
    }

    handleChipFocusOut(event) {
        const filterKey = event.currentTarget.dataset.key;
        if (this.openFilterKey !== filterKey) return;
        if (event.relatedTarget && event.currentTarget.contains(event.relatedTarget)) return;

        this.openFilterKey = null;
    }

    handleRangeChange(event) {
        const filterKey = event.target.dataset.key;
        const isStart = event.target.dataset.edge === 'from';

        this.dispatchCriteria(setSearchDayRange(this.currentCriteria, filterKey, isStart, event.target.value || ''));
    }

    handleClearAll() {
        this.openFilterKey = null;
        this.dispatchCriteria(normalizeSearchCriteria(EMPTY_SEARCH_CRITERIA));
    }

    pickOption(filterKey, optionValue, optionLabel) {
        const filter = this.findFilter(filterKey);
        if (!filter) return;

        const nextCriteria = pickSearchFilterOption(this.currentCriteria, filterKey, optionValue, optionLabel);
        const keepsMenuOpen = filter.isMultiple || (filter.isDateRange && optionValue === DATE_PRESET.CUSTOM);

        if (!keepsMenuOpen) this.closeMenu(filterKey);
        this.dispatchCriteria(nextCriteria);
    }

    fitOpenMenu() {
        if (!this.openFilterKey) return;

        const menu = this.template.querySelector(`.${MENU_CLASS}`);
        const chipRow = this.template.querySelector(`.${CHIP_ROW_CLASS}`);
        if (!menu || !chipRow) return;

        const bounds = chipRow.getBoundingClientRect();
        const anchorLeft = menu.parentElement.getBoundingClientRect().left;
        const overflow = anchorLeft + menu.offsetWidth - bounds.right;
        const offset = overflow > 0 ? Math.max(bounds.left - anchorLeft, -overflow) : 0;

        menu.style.left = `${Math.round(offset)}px`;
    }

    openMenu(filterKey, focusesItem) {
        this.openFilterKey = filterKey;
        this.pendingMenuFocusKey = filterKey;
        this.isPendingMenuFocusOnItem = focusesItem;

        if (this.findFilter(filterKey)?.listsOwners) this.loadOwners();
    }

    async loadOwners() {
        if (this.hasLoadedOwners || this.isLoadingOwners) return;

        this.isLoadingOwners = true;
        try {
            const owners = await retrieveFileExplorerOwners();
            this.owners = Array.isArray(owners) ? owners : [];
            this.hasLoadedOwners = true;
        } catch {
            this.owners = [];
        } finally {
            this.isLoadingOwners = false;
        }
    }

    findFilter(filterKey) {
        return SEARCH_FILTERS.find((filter) => filter.key === filterKey);
    }

    closeMenu(filterKey) {
        this.openFilterKey = null;
        this.pendingChipFocusKey = filterKey;
    }

    isKeyboardClick(event) {
        return event.detail === 0;
    }

    focusMenu() {
        const menu = this.template.querySelector(`.${MENU_CLASS}`);
        if (menu) menu.focus();
    }

    menuItems(filterKey) {
        return [...this.template.querySelectorAll(`.${MENU_ITEM_CLASS}[data-key="${filterKey}"]`)];
    }

    focusMenuItem(filterKey) {
        const items = this.menuItems(filterKey);
        const target = items.find((item) => item.getAttribute('aria-checked') === 'true') || items[0];
        if (target) target.focus();
    }

    moveMenuFocus(filterKey, currentItem, key) {
        const items = this.menuItems(filterKey);
        if (items.length === 0) return;

        const currentIndex = items.indexOf(currentItem);
        let nextIndex = 0;

        if (key === KEY.END) nextIndex = items.length - 1;
        else if (key === KEY.ARROW_DOWN) nextIndex = (currentIndex + 1) % items.length;
        else if (key === KEY.ARROW_UP) nextIndex = (Math.max(currentIndex, 0) - 1 + items.length) % items.length;

        items[nextIndex].focus();
    }

    focusChip(filterKey) {
        const chipButton = this.template.querySelector(`.${CHIP_BUTTON_CLASS}[data-key="${filterKey}"]`);
        if (chipButton) chipButton.focus();
    }

    dispatchCriteria(criteria) {
        this.dispatchEvent(new CustomEvent('criteriachange', { detail: { criteria } }));
    }
}
