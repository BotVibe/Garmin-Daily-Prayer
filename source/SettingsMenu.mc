import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

//! On-device cascading settings: language → translations, reminders.
class SettingsMainMenu extends WatchUi.Menu2 {

    function initialize() {
        Menu2.initialize({:title => WatchUi.loadResource(Rez.Strings.SettingsTitle) as String});
        addItem(new WatchUi.MenuItem(
            WatchUi.loadResource(Rez.Strings.SettingLanguage) as String,
            languageSubtitle(),
            :language,
            null
        ));
        addItem(new WatchUi.MenuItem(
            WatchUi.loadResource(Rez.Strings.SettingTranslation) as String,
            translationSubtitle(),
            :translation,
            null
        ));
        addItem(new WatchUi.MenuItem(
            WatchUi.loadResource(Rez.Strings.RemindersTitle) as String,
            remindersSubtitle(),
            :reminders,
            null
        ));
        addItem(new WatchUi.MenuItem(
            WatchUi.loadResource(Rez.Strings.MenuRefresh) as String,
            null,
            :refresh,
            null
        ));
        addItem(new WatchUi.MenuItem(
            WatchUi.loadResource(Rez.Strings.MenuShowVerse) as String,
            null,
            :showVerse,
            null
        ));
    }

    function languageSubtitle() as String {
        return languageName(AppConfig.getLanguageId());
    }

    function translationSubtitle() as String {
        var code = AppConfig.getTranslationCode();
        if (code.equals(Translations.RANDOM_CODE)) {
            return WatchUi.loadResource(Rez.Strings.TranslationRandom) as String;
        }
        return Translations.codeDisplayName(code);
    }

    function remindersSubtitle() as String {
        var parts = [] as Array<String>;
        for (var i = 1; i <= 3; i++) {
            if (AppConfig.isSlotEnabled(i)) {
                parts.add(AppConfig.formatSlotTime(i));
            }
        }
        if (parts.size() == 0) {
            return WatchUi.loadResource(Rez.Strings.Off) as String;
        }
        var out = parts[0] as String;
        for (var j = 1; j < parts.size(); j++) {
            out += ", " + (parts[j] as String);
        }
        return out;
    }
}

class SettingsMainDelegate extends WatchUi.Menu2InputDelegate {

    function initialize() {
        Menu2InputDelegate.initialize();
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId();
        if (id == :language) {
            WatchUi.pushView(new LanguageMenu(), new LanguageMenuDelegate(), WatchUi.SLIDE_LEFT);
        } else if (id == :translation) {
            WatchUi.pushView(new TranslationMenu(), new TranslationMenuDelegate(), WatchUi.SLIDE_LEFT);
        } else if (id == :reminders) {
            WatchUi.pushView(new RemindersMenu(), new RemindersMenuDelegate(), WatchUi.SLIDE_LEFT);
        } else if (id == :refresh) {
            WatchUi.popView(WatchUi.SLIDE_RIGHT);
            var view = getApp().getVerseView();
            if (view != null) {
                view.refresh();
            }
        } else if (id == :showVerse) {
            WatchUi.popView(WatchUi.SLIDE_RIGHT);
        }
    }

    function onBack() as Void {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }
}

class LanguageMenu extends WatchUi.Menu2 {
    function initialize() {
        Menu2.initialize({:title => WatchUi.loadResource(Rez.Strings.SettingLanguage) as String});
        var ids = Translations.languageIds();
        var current = AppConfig.getLanguageId();
        for (var i = 0; i < ids.size(); i++) {
            var lid = ids[i] as String;
            var label = languageName(lid);
            var sub = lid.equals(current) ? "✓" : null;
            addItem(new WatchUi.MenuItem(label, sub, lid, null));
        }
    }
}

class LanguageMenuDelegate extends WatchUi.Menu2InputDelegate {
    function initialize() {
        Menu2InputDelegate.initialize();
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId();
        if (id instanceof String) {
            AppConfig.setLanguageId(id as String);
            ReminderScheduler.scheduleNext();
        }
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        // Rebuild main settings to refresh subtitles
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        WatchUi.pushView(new SettingsMainMenu(), new SettingsMainDelegate(), WatchUi.SLIDE_IMMEDIATE);
    }
}

class TranslationMenu extends WatchUi.Menu2 {
    function initialize() {
        Menu2.initialize({:title => WatchUi.loadResource(Rez.Strings.SettingTranslation) as String});
        var lang = AppConfig.getLanguageId();
        var current = AppConfig.getTranslationCode();

        var randomLabel = WatchUi.loadResource(Rez.Strings.TranslationRandom) as String;
        addItem(new WatchUi.MenuItem(
            randomLabel,
            current.equals(Translations.RANDOM_CODE) ? "✓" : null,
            Translations.RANDOM_CODE,
            null
        ));

        var codes = Translations.codesForLanguage(lang);
        for (var i = 0; i < codes.size(); i++) {
            var code = codes[i] as String;
            addItem(new WatchUi.MenuItem(
                Translations.codeDisplayName(code),
                current.equals(code) ? "✓" : null,
                code,
                null
            ));
        }
    }
}

class TranslationMenuDelegate extends WatchUi.Menu2InputDelegate {
    function initialize() {
        Menu2InputDelegate.initialize();
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId();
        if (id instanceof String) {
            AppConfig.setTranslationCode(id as String);
            VerseCache.clear();
        }
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        WatchUi.pushView(new SettingsMainMenu(), new SettingsMainDelegate(), WatchUi.SLIDE_IMMEDIATE);
    }
}

class RemindersMenu extends WatchUi.Menu2 {
    function initialize() {
        Menu2.initialize({:title => WatchUi.loadResource(Rez.Strings.RemindersTitle) as String});
        addSlotItem(1);
        addSlotItem(2);
        addSlotItem(3);
    }

    function addSlotItem(slot as Number) as Void {
        var title = slotTitle(slot);
        var enabled = AppConfig.isSlotEnabled(slot);
        var sub = enabled
            ? AppConfig.formatSlotTime(slot) + " · " + (WatchUi.loadResource(Rez.Strings.On) as String)
            : WatchUi.loadResource(Rez.Strings.Off) as String;
        addItem(new WatchUi.MenuItem(title, sub, slot, null));
    }
}

class RemindersMenuDelegate extends WatchUi.Menu2InputDelegate {
    function initialize() {
        Menu2InputDelegate.initialize();
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId();
        if (id instanceof Number) {
            var slot = id as Number;
            WatchUi.pushView(new SlotMenu(slot), new SlotMenuDelegate(slot), WatchUi.SLIDE_LEFT);
        }
    }
}

class SlotMenu extends WatchUi.Menu2 {
    private var _slot as Number;

    function initialize(slot as Number) {
        _slot = slot;
        Menu2.initialize({:title => slotTitle(slot)});
        var enabled = AppConfig.isSlotEnabled(slot);
        addItem(new WatchUi.ToggleMenuItem(
            WatchUi.loadResource(Rez.Strings.SlotEnabled) as String,
            null,
            :enabled,
            enabled,
            null
        ));
        addItem(new WatchUi.MenuItem(
            WatchUi.loadResource(Rez.Strings.SlotHour) as String,
            AppConfig.getSlotHour(slot).format("%02d"),
            :hour,
            null
        ));
        addItem(new WatchUi.MenuItem(
            WatchUi.loadResource(Rez.Strings.SlotMinute) as String,
            AppConfig.getSlotMinute(slot).format("%02d"),
            :minute,
            null
        ));
    }
}

class SlotMenuDelegate extends WatchUi.Menu2InputDelegate {
    private var _slot as Number;

    function initialize(slot as Number) {
        Menu2InputDelegate.initialize();
        _slot = slot;
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId();
        if (id == :enabled) {
            if (item instanceof WatchUi.ToggleMenuItem) {
                var t = item as WatchUi.ToggleMenuItem;
                AppConfig.setSlotEnabled(_slot, t.isEnabled());
                ReminderScheduler.scheduleNext();
            }
        } else if (id == :hour) {
            WatchUi.pushView(new NumberPickMenu(0, 23, AppConfig.getSlotHour(_slot), method(:onHourPicked)), new NumberPickDelegate(), WatchUi.SLIDE_LEFT);
        } else if (id == :minute) {
            WatchUi.pushView(new NumberPickMenu(0, 59, AppConfig.getSlotMinute(_slot), method(:onMinutePicked)), new NumberPickDelegate(), WatchUi.SLIDE_LEFT);
        }
    }

    function onHourPicked(value as Number) as Void {
        AppConfig.setSlotHour(_slot, value);
        ReminderScheduler.scheduleNext();
        rebuildSlotMenu();
    }

    function onMinutePicked(value as Number) as Void {
        AppConfig.setSlotMinute(_slot, value);
        ReminderScheduler.scheduleNext();
        rebuildSlotMenu();
    }

    private function rebuildSlotMenu() as Void {
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        WatchUi.pushView(new SlotMenu(_slot), new SlotMenuDelegate(_slot), WatchUi.SLIDE_IMMEDIATE);
    }
}

typedef NumberPickCallback as Method(value as Number) as Void;

module NumberPickState {
    var callback as NumberPickCallback?;
}

class NumberPickMenu extends WatchUi.Menu2 {
    function initialize(minVal as Number, maxVal as Number, current as Number, callback as NumberPickCallback) {
        Menu2.initialize({:title => ""});
        NumberPickState.callback = callback;
        for (var v = minVal; v <= maxVal; v += 1) {
            var label = v.format("%02d");
            var sub = v == current ? "✓" : null;
            addItem(new WatchUi.MenuItem(label, sub, v, null));
        }
    }
}

class NumberPickDelegate extends WatchUi.Menu2InputDelegate {
    function initialize() {
        Menu2InputDelegate.initialize();
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId();
        var cb = NumberPickState.callback;
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        if (id instanceof Number && cb != null) {
            cb.invoke(id as Number);
        }
    }
}

function languageName(langId as String) as String {
    if (langId.equals("af")) { return WatchUi.loadResource(Rez.Strings.Lang_af) as String; }
    if (langId.equals("ar")) { return WatchUi.loadResource(Rez.Strings.Lang_ar) as String; }
    if (langId.equals("bn")) { return WatchUi.loadResource(Rez.Strings.Lang_bn) as String; }
    if (langId.equals("zh")) { return WatchUi.loadResource(Rez.Strings.Lang_zh) as String; }
    if (langId.equals("cs")) { return WatchUi.loadResource(Rez.Strings.Lang_cs) as String; }
    if (langId.equals("da")) { return WatchUi.loadResource(Rez.Strings.Lang_da) as String; }
    if (langId.equals("de")) { return WatchUi.loadResource(Rez.Strings.Lang_de) as String; }
    if (langId.equals("en")) { return WatchUi.loadResource(Rez.Strings.Lang_en) as String; }
    if (langId.equals("es")) { return WatchUi.loadResource(Rez.Strings.Lang_es) as String; }
    if (langId.equals("fa")) { return WatchUi.loadResource(Rez.Strings.Lang_fa) as String; }
    if (langId.equals("fi")) { return WatchUi.loadResource(Rez.Strings.Lang_fi) as String; }
    if (langId.equals("fr")) { return WatchUi.loadResource(Rez.Strings.Lang_fr) as String; }
    if (langId.equals("el")) { return WatchUi.loadResource(Rez.Strings.Lang_el) as String; }
    if (langId.equals("hi")) { return WatchUi.loadResource(Rez.Strings.Lang_hi) as String; }
    if (langId.equals("hu")) { return WatchUi.loadResource(Rez.Strings.Lang_hu) as String; }
    if (langId.equals("it")) { return WatchUi.loadResource(Rez.Strings.Lang_it) as String; }
    if (langId.equals("mg")) { return WatchUi.loadResource(Rez.Strings.Lang_mg) as String; }
    if (langId.equals("nl")) { return WatchUi.loadResource(Rez.Strings.Lang_nl) as String; }
    if (langId.equals("no")) { return WatchUi.loadResource(Rez.Strings.Lang_no) as String; }
    if (langId.equals("pl")) { return WatchUi.loadResource(Rez.Strings.Lang_pl) as String; }
    if (langId.equals("pt")) { return WatchUi.loadResource(Rez.Strings.Lang_pt) as String; }
    if (langId.equals("ru")) { return WatchUi.loadResource(Rez.Strings.Lang_ru) as String; }
    if (langId.equals("sk")) { return WatchUi.loadResource(Rez.Strings.Lang_sk) as String; }
    if (langId.equals("st")) { return WatchUi.loadResource(Rez.Strings.Lang_st) as String; }
    if (langId.equals("sv")) { return WatchUi.loadResource(Rez.Strings.Lang_sv) as String; }
    if (langId.equals("ur")) { return WatchUi.loadResource(Rez.Strings.Lang_ur) as String; }
    if (langId.equals("xh")) { return WatchUi.loadResource(Rez.Strings.Lang_xh) as String; }
    if (langId.equals("zu")) { return WatchUi.loadResource(Rez.Strings.Lang_zu) as String; }
    return langId;
}

function slotTitle(slot as Number) as String {
    if (slot == 1) {
        return WatchUi.loadResource(Rez.Strings.Slot1) as String;
    } else if (slot == 2) {
        return WatchUi.loadResource(Rez.Strings.Slot2) as String;
    }
    return WatchUi.loadResource(Rez.Strings.Slot3) as String;
}

