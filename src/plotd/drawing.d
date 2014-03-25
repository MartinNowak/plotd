module plotd.drawing;
import std.conv;

import cairo = cairo;

import plotd.primitives;
import plotd.binning;

// Design: One surface per plot (this makes it easier for PDFSurface support
// Get axes context
// Get plot context ( probably by first getting a subsurface from the main surface )

/*

class Dependency
{
    //string call(TYPE)();  wouldn't be mocked as it's a template
    string call()
    {
        return "Call on me, baby!";
    }
}

void funcToTest(CONTEXT)(CONTEXT cnt)
{
    cnt.fill();
}

unittest
{
    import dmocks.mocks;
    auto mocker = new Mocker();

    auto axes_surface = new cairo.ImageSurface(
            cairo.Format.CAIRO_FORMAT_ARGB32, 400, 400);
    
    //auto axes_context = cairo.Context( axes_surface );
    auto mock = mocker.mockStruct!(cairo.Context, cairo.ImageSurface )(
            axes_surface ); 

    mocker.expect(mock.fill()).repeat( 1 );
    mocker.replay;
    funcToTest(mock);
    mocker.verify;
}
*/

/// Create the plot surface
cairo.Surface create_plot_surface() {
    auto surface = new cairo.ImageSurface(
            cairo.Format.CAIRO_FORMAT_ARGB32, 400, 400);
    auto context = cairo.Context( surface );
    clear( context );
    return surface;
}

/// Save surface to a file
void save( cairo.Surface surface ) {
    (cast(cairo.ImageSurface)( surface )).writeToPNG( "example.png" );
}

/// Get axes_context from a surface
cairo.Context axes_context_from_surface( cairo.Surface surface, Bounds bounds ) {
    auto context = cairo.Context( surface );

    context.translate( 100, 300 );
    context.scale( 300.0/(bounds.max_x-bounds.min_x), 
            -300.0/(bounds.max_y - bounds.min_y) );
    context.translate( -bounds.min_x, -bounds.min_y );
    context.setFontSize( 14.0 );
    return context;
}

/// Get plot_context from a surface
cairo.Context plot_context_from_surface( cairo.Surface surface, Bounds bounds ) {
    // Create a sub surface. Makes sure everything is plotted within plot surface
    auto plot_surface = cairo.Surface.createForRectangle( surface, 
            cairo.Rectangle!double( 100, 0, 300, 300 ) );
    auto context = cairo.Context( plot_surface );
    context.translate( 0, 300 );
    context.scale( 300.0/(bounds.max_x-bounds.min_x), 
            -300.0/(bounds.max_y - bounds.min_y) );
    context.translate( -bounds.min_x, -bounds.min_y );
    context.setFontSize( 14.0 );
    return context;
}

/** Draw point onto context
    
  Template function to make it Mockable

  */
CONTEXT draw_point(CONTEXT)( const Point point, CONTEXT context ) {
    auto width_height = context.deviceToUserDistance( 
            cairo.Point!double( 10.0, 10.0 ) );
    context.rectangle(
            point.x-width_height.x/2.0, point.y-width_height.y/2.0, 
                width_height.x, width_height.y );
    context.fill();
    return context;
}

/*
For some reason the expect for deviceToUserDistance is not working correctly

   unittest {
    import dmocks.mocks;
    auto mocker = new Mocker();

    auto surface = create_plot_surface();
    auto mock = mocker.mockStruct!(cairo.Context, cairo.Surface )(
            surface ); 

    mocker.expect(mock.fill()).repeat( 2 );
    auto distance = cairo.Point!double( 10, 10 );
    mocker.expect(mock.deviceToUserDistance( 
            distance ) ).returns( cairo.Point!double( 20.0/300.0,
                20.0/300.0 ));

    double scale = 10.0/300.0;
    mocker.expect(mock.rectangle( 0-scale, 0-scale, scale*2, scale*2 )).repeat(1);
    mocker.expect(mock.rectangle( -1-scale, -1-scale, scale*2, scale*2 )).repeat(1);
    mocker.replay;
    draw_point( Point( 0, 0 ), mock );
    draw_point( Point( -1, -1 ), mock );
    mocker.verify;
}*/

CONTEXT draw_line(CONTEXT)( const Point from, const Point to, CONTEXT context ) {
    context.moveTo( from.x, from.y );
    context.lineTo( to.x, to.y );
    context.save();
    context.identityMatrix();
    context.stroke();
    context.restore();
    return context;
}

unittest {
    import dmocks.mocks;
    auto mocker = new Mocker();

    auto surface = create_plot_surface();
    auto mock = mocker.mockStruct!(cairo.Context, cairo.Surface )(
            surface ); 

    mocker.expect(mock.moveTo( 0.0, 0.0 )).repeat(1);
    mocker.expect(mock.lineTo( -1.0, -1.0 )).repeat(1);
    mocker.expect(mock.stroke()).repeat(1);
    mocker.expect(mock.save()).repeat(1);
    mocker.expect(mock.identityMatrix()).repeat(1);
    mocker.expect(mock.restore()).repeat(1);
    mocker.replay;
    draw_line( Point( 0, 0 ), Point( -1, -1 ), mock );
    mocker.verify;
}

/**
  Draw axes onto the given context
  */
CONTEXT draw_axes(CONTEXT)( const Bounds bounds, CONTEXT context ) {
    auto xaxis = new Axis( bounds.min_x, bounds.max_x );
    xaxis = adjust_tick_width( xaxis, 5 );

    auto yaxis = new Axis( bounds.min_y, bounds.max_y );
    yaxis = adjust_tick_width( yaxis, 5 );

    // Draw xaxis
    context = draw_line( Point( xaxis.min, yaxis.min ), 
            Point( xaxis.max, yaxis.min ), context );
    // Draw ticks
    auto tick_x = xaxis.min_tick;
    auto tick_size = tick_length(yaxis);
    while( tick_x < xaxis.max ) {
        context = draw_line( Point( tick_x, yaxis.min ),
            Point( tick_x, yaxis.min + tick_size ), context );
        context = draw_text( tick_x.to!string, 
                Point( tick_x, yaxis.min - 1.5*tick_size ), context );
        tick_x += xaxis.tick_width;
    }

    // Draw yaxis
    context = draw_line( Point( xaxis.min, yaxis.min ), 
            Point( xaxis.min, yaxis.max ), context );
    // Draw ticks
    auto tick_y = yaxis.min_tick;
    tick_size = tick_length(yaxis);
    while( tick_y < yaxis.max ) {
        context = draw_line( Point( xaxis.min, tick_y ),
            Point( xaxis.min + tick_size, tick_y ), context );
        context = draw_text( tick_y.to!string, 
                Point( xaxis.min - 1.5*tick_size, tick_y ), context );
        tick_y += yaxis.tick_width;
    }

    return context;
}

CONTEXT draw_text(CONTEXT)( string text, const Point location, CONTEXT context ) {
    context.moveTo( location.x, location.y ); 
    context.save();
    context.identityMatrix();
    context.showText( text );
    context.restore();
    return context;
}

unittest {
    import dmocks.mocks;
    auto mocker = new Mocker();

    auto surface = create_plot_surface();
    auto mock = mocker.mockStruct!(cairo.Context, cairo.Surface )(
            surface ); 

    mocker.expect(mock.moveTo( 0.0, 0.0 )).repeat(1);
    mocker.expect(mock.save()).repeat(1);
    mocker.expect(mock.identityMatrix()).repeat(1);
    mocker.expect(mock.showText( "text" )).repeat(1);
    mocker.expect(mock.restore()).repeat(1);
    mocker.replay;
    draw_text( "text", Point( 0, 0 ), mock );
    mocker.verify;
}

CONTEXT draw_bins( T : size_t, CONTEXT )( CONTEXT context, Bins!T bins ) {
    foreach( x, count; bins ) {
        context = draw_line( Point( x, 0 ), 
                Point( x, cast(double)(count)/bins.max_size ),
                context );
        context = draw_line( Point( x, cast(double)(count)/bins.max_size ), 
                Point( x + bins.width, cast(double)(count)/bins.max_size ),
                context );
        context = draw_line( 
                Point( x + bins.width, cast(double)(count)/bins.max_size ), 
                Point( x + bins.width, 0 ),
                context );
      }
    return context;
}

CONTEXT clear( CONTEXT )( CONTEXT context ) {
    context.save();
    context = color( context, Color.white );
    context.paint();
    context.restore();
    return context;
}

unittest {
    import dmocks.mocks;
    auto mocker = new Mocker();

    auto surface = create_plot_surface();
    auto mock = mocker.mockStruct!(cairo.Context, cairo.Surface )(
            surface );
    mocker.expect( mock.save() ).repeat(1);
    mocker.expect( mock.setSourceRGBA( 1, 1, 1, 1 ) ).repeat(1);
    mocker.expect( mock.paint() ).repeat(1);
    mocker.expect( mock.restore() ).repeat(1);
    mocker.replay;
    clear( mock );
    mocker.verify;
}

CONTEXT color( CONTEXT )( CONTEXT context, const Color color ) {
    context.setSourceRGBA( color.r, color.g, color.b, color.a );
    return context;
}
