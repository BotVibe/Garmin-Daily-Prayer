import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

//! Soft dark teal backdrop — low redraw cost, OLED-friendly.
class BackgroundDrawable extends WatchUi.Drawable {
    //! Layouts instantiate custom drawables with the generated parameter dictionary.
    function initialize(params as Dictionary) {
        Drawable.initialize(params);
    }

    function draw(dc as Graphics.Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        dc.setColor(0x0C1C24, 0x0C1C24);
        dc.fillRectangle(0, 0, w, h);

        // Subtle radial atmosphere without multi-layer shadows
        dc.setColor(0x123440, Graphics.COLOR_TRANSPARENT);
        var r = (w < h ? w : h) / 2;
        dc.fillCircle(w / 2, h / 2, r);
        dc.setColor(0x0C1C24, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(w / 2, h / 2, (r * 3) / 5);
    }
}
