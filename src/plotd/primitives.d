module plotd.primitives;

import std.math;
import std.stdio;
import std.string;
import std.conv;

class Color {
    double r = 1, g = 1, b = 1, a = 1;
    this( double red, double green, double blue, double alpha ) { 
        r = red; g = green; b = blue; a = alpha; }

    this( string value ) {
        auto rgba = value.split( "," );
        assert( rgba.length == 4 );
        r = to!double(rgba[0]); g = to!double(rgba[1]); 
        b = to!double(rgba[2]); a = to!double(rgba[3]);
    }

    unittest {
        assert( new Color( "0.1,0.2,0.3,0.4" ) == new Color( 0.1, 0.2, 0.3, 0.4 ) );
    }

    override bool opEquals( Object o ) const {
        auto color = cast( typeof( this ) ) o;
        return ( r == color.r &&
                g == color.g &&
                b == color.b &&
                a == color.a );
    }

    static Color black() {
        auto color = new Color( 0, 0, 0, 1 );
        return color;
    }

    static Color white() {
        auto color = new Color( 1, 1, 1, 1 );
        return color;
    }


    unittest {
        auto col1 = Color.black;
        auto col2 = Color.black;
        assert( col1.r == col2.r );
        assert( col1.g == col2.g );
        assert( col1.b == col2.b );
        assert( col1.a == col2.a );
        assert ( col1.opEquals( col2 ) );
        assert ( col1 == col2 );
    }
}

struct Bounds {
    double min_x;
    double max_x;
    double min_y;
    double max_y;

    this( double my_min_x, double my_max_x, double my_min_y, double my_max_y ) {
        min_x = my_min_x;
        max_x = my_max_x;
        min_y = my_min_y;
        max_y = my_max_y;
    }
}

struct Point {
    double x;
    double y;
    this( double my_x, double my_y ) {
        x = my_x;
        y = my_y;
    }

    this( string value ) {
        auto coords = value.split( "," );
        assert( coords.length == 2 );
        x = to!double(coords[0]); 
        y = to!double(coords[1]);
    }

    unittest {
        assert( Point( "1.0,0.1" ) == Point( 1.0, 0.1 ) );
    }

    bool opEquals( const Point point ) {
        return point.x == x && point.y == y;
    }
}

Point convert_coordinates( const Point point, const Bounds orig_bounds, 
        const Bounds new_bounds ) {
    double new_x = new_bounds.min_x + (new_bounds.max_x-new_bounds.min_x)*(point.x-orig_bounds.min_x)/(orig_bounds.max_x-orig_bounds.min_x);
    double new_y = new_bounds.min_y + (new_bounds.max_y-new_bounds.min_y)*(point.y-orig_bounds.min_y)/(orig_bounds.max_y-orig_bounds.min_y);
    return Point( new_x, new_y );
}

unittest {
    assert( convert_coordinates( Point( 0.5, 0.1 ), Bounds( -1, 1, -1, 1 ),
                Bounds( 50, 100, -100, -50 ) ) == Point( 87.5, -72.5 ) );
}

alias int LineId;

class LineState {
    Color color;
    Point end_point;
    LineId id;
}

class Lines {
    /// Returns an unused (new) line_id
    LineId new_line_id() {
        last_id++;
        return last_id;
    }

    void add_line( LineId id, Point point ) {
        auto state = new LineState;
        state.color = Color.black;
        state.end_point = point;
        state.id = id;
        lines[id] = state;
    }

    unittest {
        auto lines = new Lines;
        lines.add_line( 1, Point( 1, 2 ) );
        assert( lines.lines.length == 1 );
        assert( lines.lines[1].color == Color.black ); // Should implement equals for color
        assert( lines.lines[1].end_point == Point( 1, 2 ) );
    }

    private:
        LineState[LineId] lines;
        LineId last_id = 0;
}

class Axis {
    this( double newmin, double newmax ) {
        min = newmin;
        max = newmax;
        min_tick = min;
    }
  string label;
  double min = -1;
  double max = 1;
  double min_tick = -1;
  double tick_width = 0.2;
}

/**
    Calculate optimal tick width given an axis and an approximate number of ticks
    */
Axis adjust_tick_width( Axis axis, size_t approx_no_ticks ) {
    auto axis_width = axis.max-axis.min;
    auto scale = cast(int) ceil(log10( axis_width )) - 1;
    auto acceptables = [ 0.1, 0.5, 1.0 ]; // Only accept ticks of these sizes
    auto approx_width = pow(10.0, -scale)*(axis_width)/approx_no_ticks;
    // Find closest acceptable value
    double best = acceptables[0];
    double diff = abs( approx_width - best );
    foreach ( accept; acceptables[1..$] ) { 
        if (abs( approx_width - accept ) < diff) {
            best = accept;
            diff = abs( approx_width - accept );
        }
    }
    axis.tick_width = best*pow(10.0, scale);

    // Find good min_tick
    axis.min_tick = ceil(axis.min/pow(10.0, -scale))*pow(10.0, scale);
    while (axis.min_tick - axis.tick_width > axis.min)
        axis.min_tick -= axis.tick_width;
    return axis;
}

unittest {
    adjust_tick_width( new Axis( 0, .4 ), 5 );
    adjust_tick_width( new Axis( 0, 4 ), 8 );
    assert( adjust_tick_width( new Axis( 0, 4 ), 5 ).tick_width == 1.0 );
    assert( adjust_tick_width( new Axis( 0, 4 ), 8 ).tick_width == 0.5 );
    assert( adjust_tick_width( new Axis( 0, 0.4 ), 5 ).tick_width == 0.1 );
    assert( adjust_tick_width( new Axis( 0, 40 ), 8 ).tick_width == 5 );
    assert( adjust_tick_width( new Axis( -0.1, 4 ), 8 ).tick_width == 0.5 );
    assert( adjust_tick_width( new Axis( -0.1, 4 ), 8 ).min_tick == 0.0 );
    assert( adjust_tick_width( new Axis( 0.1, 4 ), 8 ).min_tick == 0.5 );
    assert( adjust_tick_width( new Axis( 1, 40 ), 8 ).min_tick == 5 );
}

/// Calculate tick length
double tick_length( const Axis axis ) {
    return (axis.max-axis.min)/25.0;
}

unittest {
    auto axis = new Axis( -1, 1 );
    assert( tick_length( axis ) == 0.08);
}
