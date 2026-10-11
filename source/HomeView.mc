import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

//! Lightweight home / brand frame. The app launches into VerseView for the
//! primary path (manual open + reminder accept). This view remains available
//! if a future entry point wants an intermediate screen.
class HomeView extends WatchUi.View {

    function initialize() {
        View.initialize();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();

        dc.setColor(0x0C1C24, 0x0C1C24);
        dc.fillRectangle(0, 0, w, h);
        dc.setColor(0x123440, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(w / 2, h / 2, (w < h ? w : h) / 2);

        dc.setColor(0xE8DCC4, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            w / 2,
            h / 2 - dc.getFontHeight(Graphics.FONT_MEDIUM),
            Graphics.FONT_MEDIUM,
            WatchUi.loadResource(Rez.Strings.AppName) as String,
            Graphics.TEXT_JUSTIFY_CENTER
        );

        dc.setColor(0xC8A060, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            w / 2,
            h / 2 + 8,
            Graphics.FONT_TINY,
            WatchUi.loadResource(Rez.Strings.MenuShowVerse) as String,
            Graphics.TEXT_JUSTIFY_CENTER
        );
    }
}

class HomeDelegate extends WatchUi.BehaviorDelegate {
    function initialize() {
        BehaviorDelegate.initialize();
    }

    function onSelect() as Boolean {
        var view = new VerseView(false);
        var delegate = new VerseDelegate();
        delegate.setView(view);
        WatchUi.switchToView(view, delegate, WatchUi.SLIDE_LEFT);
        return true;
    }

    function onMenu() as Boolean {
        WatchUi.pushView(new SettingsMainMenu(), new SettingsMainDelegate(), WatchUi.SLIDE_LEFT);
        return true;
    }
}
