import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

//! Vertical spinner column for WatchUi.Picker (hour / minute wheels).
class NumberFactory extends WatchUi.PickerFactory {
    private var _start as Number;
    private var _stop as Number;
    private var _increment as Number;
    private var _format as String;

    function initialize(start as Number, stop as Number, increment as Number, options as Dictionary?) {
        PickerFactory.initialize();
        _start = start;
        _stop = stop;
        _increment = increment;
        _format = "%d";
        if (options != null && (options as Dictionary).hasKey(:format)) {
            _format = (options as Dictionary).get(:format) as String;
        }
    }

    function getIndex(value as Number) as Number {
        return ((value - _start) / _increment) as Number;
    }

    function getValue(index as Number) as Object? {
        return _start + (index * _increment);
    }

    function getSize() as Number {
        return (((_stop - _start) / _increment) + 1) as Number;
    }

    function getDrawable(index as Number, selected as Boolean) as Drawable? {
        var value = getValue(index) as Number;
        return new WatchUi.Text({
            :text => value.format(_format),
            :color => Graphics.COLOR_WHITE,
            :font => selected ? Graphics.FONT_LARGE : Graphics.FONT_MEDIUM,
            :locX => WatchUi.LAYOUT_HALIGN_CENTER,
            :locY => WatchUi.LAYOUT_VALIGN_CENTER
        });
    }
}
