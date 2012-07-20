/**
  Set of filters for alignments. 
  All share a common interface and can be easily combined.
*/
module filter;

import std.regex;
import alignment;
import tagvalue;
import validation.alignment;

/// Common interface for all filters
interface Filter {
    bool accepts(ref Alignment a) const;
}

/// Filter which accepts all alignments
final class NullFilter : Filter {
    bool accepts(ref Alignment a) const {
        return true;
    }
}

/// Filter which accepts only alignments with big enough mapping quality
final class MappingQualityFilter : Filter {
    private ubyte _min_q;

    this(ubyte minimal_quality) {
        _min_q = minimal_quality;
    }

    bool accepts(ref Alignment a) const {
        return a.mapping_quality >= _min_q;
    }
}

/// Filter which accepts only alignments with a given read group
final class ReadGroupFilter : Filter {
    private string _rg;

    this(string read_group) {
        _rg = read_group;
    }

    bool accepts(ref Alignment a) const {
        auto rg = a["RG"];
        if (!rg.is_string || (to!string(rg) != _rg)) {
            return false;
        }
        return true;
    }
}

/// Validating filter
final class ValidAlignmentFilter : Filter {
    
    bool accepts(ref Alignment a) const {
        return isValid(a);
    }
}

/// Intersection of two filters
final class AndFilter : Filter {
    private Filter _a, _b;

    this(Filter a, Filter b) { _a = a; _b = b; }

    bool accepts(ref Alignment a) const {
        return _a.accepts(a) && _b.accepts(a);
    }
}

/// Union of two filters
final class OrFilter : Filter {
    private Filter _a, _b;

    this(Filter a, Filter b) { _a = a, _b = b; }

    bool accepts(ref Alignment a) const {
        return _a.accepts(a) || _b.accepts(a);
    }
}

/// Negation of a filter
final class NotFilter : Filter {
    private Filter _a;

    this(Filter a) { _a = a; }
    bool accepts(ref Alignment a) const {
        return !_a.accepts(a);
    }
}

/// Filter alignments which has $(D flagname) flag set
final class FlagFilter(string flagname) : Filter {
    bool accepts(ref Alignment a) const {
        mixin("return a." ~ flagname ~ ";");
    }
}

/// Filtering integer fields
final class IntegerFieldFilter(string op) : Filter {
    private long _value;
    private string _fieldname;
    this(string fieldname, long value) {
        _fieldname = fieldname;
        _value = value;
    }
    bool accepts(ref Alignment a) const {
        switch(_fieldname) {
            case "ref_id": mixin("return a.ref_id " ~ op ~ "_value;");
            case "position": mixin("return a.position " ~ op ~ "_value;");
            case "mapping_quality": mixin("return a.mapping_quality " ~ op ~ "_value;");
            case "sequence_length": mixin("return a.sequence_length " ~ op ~ "_value;");
            case "mate_ref_id": mixin("return a.next_ref_id " ~ op ~ "_value;");
            case "mate_position": mixin("return a.next_pos " ~ op ~ "_value;");
            case "template_length": mixin("return a.template_length " ~ op ~ "_value;");
            default: throw new Exception("unknown integer field '" ~ _fieldname ~ "'");
        }
    }
}

/// Filtering integer tags
final class IntegerTagFilter(string op) : Filter {
    private long _value;
    private string _tagname;

    this(string tagname, long value) {
        _tagname = tagname;
        _value = value;
    }

    bool accepts(ref Alignment a) const {
        auto v = a[_tagname];
        if (!v.is_integer && !v.is_float) 
            return false;
        if (v.is_float) {
            mixin(`return cast(float)v` ~ op ~ `_value;`);
        } else {
            mixin(`return cast(long)v` ~ op ~ `_value;`);
        }
    }
}

/// Filtering string fields
final class StringFieldFilter(string op) : Filter {
    private string _value;
    private string _fieldname;
    this(string fieldname, string value) {
        _fieldname = fieldname;
        _value = value;
    }
    bool accepts(ref Alignment a) const {
        switch(_fieldname) {
            case "read_name": mixin("return a.read_name " ~ op ~ "_value;");
            default: throw new Exception("unknown string field '" ~ _fieldname ~ "'");
        }
    }
}

/// Filtering string tags
final class StringTagFilter(string op) : Filter {
    private string _value;
    private string _tagname;

    this(string tagname, string value) {
        _tagname = tagname;
        _value = value;
    }

    bool accepts(ref Alignment a) const {
        auto v = a[_tagname];
        if (!v.is_string) {
            return false;
        }
        mixin(`return cast(string)v` ~ op ~ `_value;`);
    }
}

/// Filtering string fields with a regular expression
final class RegexpFieldFilter(string fieldname) : Filter {
    private Regex!char _pattern;
    
    this(Regex!char pattern) {
        _pattern = pattern;
    }

    bool accepts(ref Alignment a) const {
        mixin("return !match(a." ~ fieldname ~ ", _pattern).empty;");
    }
}

/// Filtering string tags with a regular expression
final class RegexpTagFilter : Filter { 
    private string _tagname;
    alias typeof(regex("")) Regex;
    private Regex _pattern;
    
    this(string tagname, Regex pattern) {
        _tagname = tagname;
        _pattern = pattern;
    }

    bool accepts(ref Alignment a) const {
        auto v = a[_tagname];
        if (!v.is_string) {
            return false;
        }
        mixin("return !match(cast(string)v, cast()_pattern).empty;");
    }
}