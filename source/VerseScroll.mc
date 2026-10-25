import Toybox.Lang;

//! Pure helpers for long-verse scrolling (mirrored in tools/dailyverse_lib/verse_layout.py).
module VerseScroll {

    //! True when lineCount * lineHeight does not fit in areaHeight.
    function needsScroll(lineCount as Number, lineHeight as Number, areaHeight as Number) as Boolean {
        if (lineCount <= 0 || lineHeight <= 0 || areaHeight <= 0) {
            return false;
        }
        return (lineCount * lineHeight) > areaHeight;
    }

    //! Clamp the first visible line index into a valid range.
    function clampOffset(offset as Number, totalLines as Number, visibleLines as Number) as Number {
        if (visibleLines <= 0 || totalLines <= 0) {
            return 0;
        }
        var maxOffset = totalLines - visibleLines;
        if (maxOffset < 0) {
            maxOffset = 0;
        }
        if (offset < 0) {
            return 0;
        }
        if (offset > maxOffset) {
            return maxOffset;
        }
        return offset;
    }

    //! Lines advanced per next/previous page (one line of overlap).
    function pageDelta(visibleLines as Number) as Number {
        if (visibleLines <= 1) {
            return 1;
        }
        return visibleLines - 1;
    }

    //! Whether content remains below the current viewport.
    function moreBelow(offset as Number, totalLines as Number, visibleLines as Number) as Boolean {
        if (visibleLines <= 0) {
            return false;
        }
        return (offset + visibleLines) < totalLines;
    }
}
