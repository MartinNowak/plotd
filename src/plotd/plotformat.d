/*
	 -------------------------------------------------------------------

	 Copyright (C) 2014, Edwin van Leeuwen

	 This file is part of plotd plotting library.

	 Plotd is free software; you can redistribute it and/or modify
	 it under the terms of the GNU General Public License as published by
	 the Free Software Foundation; either version 3 of the License, or
	 (at your option) any later version.

	 Plotd is distributed in the hope that it will be useful,
	 but WITHOUT ANY WARRANTY; without even the implied warranty of
	 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
	 GNU General Public License for more details.

	 You should have received a copy of the GNU General Public License
	 along with Plotd. If not, see <http://www.gnu.org/licenses/>.

	 -------------------------------------------------------------------
	 */

/**
	High level interface to the plotting library
	*/
module plotd.plotformat;

import std.conv;
import std.range;

import plotd.drawing;
import plotd.primitives;

version (assert) {
	import std.stdio : writeln;
}

/// Draw function on our plot
CONTEXT drawFunction(CONTEXT)( double delegate(double) func,
		Bounds bounds, CONTEXT context ) {
	auto points = iota( bounds.min_x, bounds.max_x, 
				bounds.width/100.0 )
			.map!( a => Point( a, func( a ) ) );

	auto from = points[0];
	foreach( to; points[1..$] ) {
		context = drawLine( from, to, context );
		from = to;
	}
	return context;
}

/// Class that holds all state to do with one figure 
class PlotState( string fileFormat = "png" ) {
	Bounds plotBounds = Bounds( 0, 1, 0, 1 );
	Bounds marginBounds = Bounds( 70, 400, 70, 400 );

    string name = "plotcli" ~ fileFormat;

	cairo.Surface surface;
	cairo.Context axesContext;
	cairo.Context plotContext;
}

unittest {
  new PlotState!"png";
}

/// Instantiate a new plot
PlotState!("png") createPlotStatePNG( Bounds plotBounds, Bounds marginBounds ) {
    auto plot = new PlotState!"png";
    plot.plotBounds = plotBounds;
    plot.marginBounds = marginBounds;

    plot.surface = createPlotSurface( plot.marginBounds.max_x.to!int, 
            plot.marginBounds.max_y.to!int );

    // setup axes
    plot.axesContext = axesContextFromSurface( plot.surface, 
            plot.plotBounds, plot.marginBounds );

    plot.axesContext = drawAxes( plot.plotBounds, plot.axesContext );

    plot.plotContext = plotContextFromSurface( plot.surface, 
            plot.plotBounds, plot.marginBounds );

    return plot;
}

/++ 
Create plotState of type T with given name, plot bounds and margin bounds

Name gets as extension the given type
+/ 
PlotState!T createPlotState(alias string T)( string name, Bounds plotBounds, 
        Bounds marginBounds ) {
    auto plot = new PlotState!T;
    plot.plotBounds = plotBounds;
    plot.marginBounds = marginBounds;
    plot.name = name ~ "." ~ T;

    // TODO Here the typing should start to happen
    static if (T == "pdf") {
        plot.surface = createPlotSurfacePDF( plot.name, 
                plot.marginBounds.max_x.to!int, 
                plot.marginBounds.max_y.to!int );
    } else {
        plot.surface = createPlotSurface( plot.marginBounds.max_x.to!int, 
                plot.marginBounds.max_y.to!int );
    }

    // setup axes
    plot.axesContext = axesContextFromSurface( plot.surface, 
            plot.plotBounds, plot.marginBounds );

    plot.axesContext = drawAxes( plot.plotBounds, plot.axesContext );

    plot.plotContext = plotContextFromSurface( plot.surface, 
            plot.plotBounds, plot.marginBounds );

    return plot;
}

unittest {
    auto plot = createPlotState!"pdf"( "test", Bounds( 0, 1, 0, 1 ),
         Bounds( 10, 100, 10, 100 ) );
    assert( plot.name == "test.pdf" );
    // TODO Test that this works
    assert( plot.surface.getType() == 
            cairo.SurfaceType.CAIRO_SURFACE_TYPE_PDF );
}

/// Draw a range of points as a line
void drawRange(RANGE)( RANGE range, PlotState plot ) {
	if (!range.empty) {
		auto firstPoint = range.front;
		range.popFront;
		while (!range.empty) {
			auto nextPoint = range.front;
			range.popFront;
			plot.plotContext = 
				drawLine( firstPoint, nextPoint, plot.plotContext );
			firstPoint = nextPoint;
		}
	}
}

/// Draw function on our plot
void drawFunction(T)( double delegate(double) func,
		PlotState!T plot ) {
	iota( plot.plotBounds.min_x, plot.plotBounds.max_x, 
				plot.plotBounds.width/100.0 )
			.map!( a => Point( a, func( a ) ) ).drawRange( plot );
}

/// Draw point on the plot
void draw(T)( Point point, PlotState!T plot ) {
	plot.plotContext = drawPoint( point, plot.plotContext );
}

/// Save plot to a file if format is "png" does nothing otherwise
void save(T)( PlotState!T plot ) {
    static if (T=="png")
        (cast(cairo.ImageSurface)( plot.surface )).writeToPNG( plot.name );
}