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

module plotd.data.binning;

import std.algorithm : reduce;
import std.array;
import std.conv : to;
import std.range;
import plotd.primitives : Bounds;

version(unittest)
{
    import std.stdio;

}
version(assert)
{
    import std.stdio;

}

/**
  The struct Bins is a container holding binned data
 */

struct Bins(T)
{
    double min;
    double width;
    @property double max()
    {
        return min + width * (mybins.length);
    }

    
    /// How many bins does the container have
    @property size_t length()
    {
        return mybins.length;
    }

    
    /// Set length/number of bins
    @property void length(size_t noBins)
    {
        mybins.length = noBins;
    }

    
    /// save the container position
    @property Bins!T save()
    {
        return this;
    }

    
    /// Access bin by index
    ref T opIndex(size_t index)
    {
        return mybins[index];
    }

    int opApply(int delegate(ref T) dg)
    {
        int result;
        double x = min;
        foreach (el; mybins)
        {
            result = dg(el);
            if (result)
                break;
            x += width;
        }
        return result;
    }

    int opApply(int delegate(double, ref T) dg)
    {
        int result;
        double x = min;
        foreach (el; mybins)
        {
            result = dg(x, el);
            if (result)
                break;
            x += width;
        }
        return result;
    }

    private  : T[] mybins;
}


/// For loop over Bins
unittest
{
    Bins!size_t bins;
    bins.min = -1;
    bins.width = 0.5;
    bins.mybins = [1, 2, 3, 4];
    size_t correct_el = 1;
    foreach (el; bins)
    {
        assert(correct_el == el);
        correct_el++;
    }
    double correct_x = bins.min;
    correct_el = 1;
    foreach (x, el; bins)
    {
        assert(correct_x == x);
        assert(correct_el == el);
        correct_x += bins.width;
        correct_el++;
    }
}


/// Number of Bins
unittest
{
    Bins!size_t bins;
    bins.min = -1;
    bins.width = 0.5;
    bins.length = 3;
    assert(bins.length == 3);
    assert(equal(bins.mybins, [0, 0, 0]));
}


/**
  Calculate bin id based on data value and Bins

  TODO implement this for multidimensional bins
  */

size_t binId(T)(in Bins!T bins, double data)
{
    assert(data >= bins.min);
    return cast(size_t)((data - bins.min) / bins.width);
}

unittest
{
    Bins!size_t bins;
    bins.min = -1;
    bins.width = 0.5;
    assert(binId!size_t(bins, -1.0) == 0);
    assert(binId(bins, -0.5) == 1);
    assert(bins.binId(-0.25) == 1);
}

size_t[] binIDs(T)(Bins!T bins, in double[] data)
{
    size_t[] ids = [binId(bins, data[0])];
    static if (__traits(compiles, binIDs(bins.mybins[0], data[1 .. $])))
    {
        ids ~= binIDs(bins.mybins[0], data[1 .. $]);
    }
    return ids;
}

unittest
{
    Bins!size_t bins;
    bins.min = -1;
    bins.width = 0.5;
    assert(binIDs!size_t(bins, [-1.0]) == [0]);
    assert(binIDs(bins, [-0.5]) == [1]);
    assert(bins.binIDs([-0.25]) == [1]);
    Bins!(Bins!size_t) mbins;
    mbins.min = -1;
    mbins.width = 0.5;
    mbins.mybins = [bins, bins];
    assert(binIDs(mbins, [-1.0, -1.0]) == [0, 0]);
    assert(binIDs(mbins, [-0.5, -1.0]) == [1, 0]);
    Bins!(Bins!size_t) mbins2;
    mbins2.min = 5;
    mbins2.width = 1.0;
    mbins2.mybins = [bins, bins];
    assert(binIDs(mbins2, [5, -1.0]) == [0, 0]);
    assert(binIDs(mbins2, [6.5, -1.0]) == [1, 0]);
}


/**
  Add data to the given bin id

  bin_ids is an array in case of multidimensional bins

  Ignore values that fall outside of the existing bin range
 */

Bins!T addDataToBin(T)(Bins!T bins, const size_t[] binIds)
{
    static if (__traits(compiles, bins[binIds[0]].addDataToBin(binIds[1 .. $])))
    {
        if (binIds[0] < bins.length)
        {
            bins[binIds[0]].addDataToBin(binIds[1 .. $]);
        }
    }
    else
    {
        if (binIds[0] < bins.length)
        {
            bins[binIds[0]]++;
        }
    }
    return bins;
}

unittest
{
    Bins!size_t bins;
    bins.min = -1;
    bins.width = 0.5;
    bins.mybins = [1, 2, 3, 4];
    bins.addDataToBin([1]);
    assert(bins.mybins[1] == 3);
    bins.addDataToBin([3]);
    assert(bins.mybins[3] == 5);
    Bins!(Bins!size_t) mbins;
    mbins.min = -1;
    mbins.width = 0.5;
    mbins.mybins = [bins, bins];
    mbins.addDataToBin([1, 2]);
    assert(mbins.mybins[1].mybins[2] == 4);
    mbins.addDataToBin([1, 3]);
    assert(mbins.mybins[1].mybins[3] == 6);
}

Bins!T addData(T)(Bins!T bins, const double[] data)
{
    return bins.addDataToBin(bins.binIDs!T(data));
}

unittest
{
    Bins!size_t bins;
    bins.min = -1;
    bins.width = 0.5;
    bins.mybins = [1, 2, 3, 4];
    bins.addData([-0.1]);
    assert(bins.mybins[1] == 3);
    bins.addData([0.9]);
    assert(bins.mybins[3] == 5);
    Bins!(Bins!size_t) mbins;
    mbins.min = -1;
    mbins.width = 0.5;
    mbins.mybins = [bins, bins];
    mbins.addData([-0.1, 0.1]);
    assert(mbins.mybins[1].mybins[2] == 4);
    mbins.addData([-0.1, -1.0]);
    assert(mbins.mybins[0].mybins[1] == 3);
}

unittest
{
    Bins!size_t bins;
    bins.min = -1;
    bins.width = 0.5;
    bins.mybins = [1, 2, 3, 4];
    Bins!(Bins!size_t) mbins;
    mbins.min = 5;
    mbins.width = 1.0;
    mbins.mybins = [bins, bins];
    mbins.addData([5, 0.1]);
    assert(mbins.mybins[0].mybins[2] == 4);
    mbins.addData([6, -1]);
    assert(mbins.mybins[1].mybins[0] == 2);
}


/**
	Calculate bounds that will at least cover the given percentage of data
	*/

Bounds optimalBounds(T)(Bins!T bins, double coverage = 0.95)
{
    Bounds bounds;
    bounds.min_y = 0;
    size_t maxCount = 0;
    size_t maxID = 0;
    double[2] sides = [0, 0];
    double sum = 0;
    foreach (i; 0 .. bins.length)
    {
        auto count = bins.mybins[i];
        sum += count;
        if (count > maxCount)
        {
            maxCount = count;
            maxID = i;
            sides[0] += sides[1];
            sides[1] = maxCount;
        }
        else if (sides[1] > 0)
            sides[1] += count;
        else sides[0] += count;
    }
    size_t[2] sideIDs = [maxID, maxID + 1];
    sides[1] -= maxCount;
    double covered = (maxCount.to!double) / sum;
    while (covered < coverage)
    {
        if (sides[0] > sides[1])
        {
            --sideIDs[0];
            sides[0] -= bins.mybins[sideIDs[0]];
            covered += bins.mybins[sideIDs[0]].to!double / sum;
        }
        else
        {
            sides[1] -= bins.mybins[sideIDs[1]];
            covered += bins.mybins[sideIDs[1]].to!double / sum;
            ++sideIDs[1];
        }
    }
    bounds.min_x = bins.min + sideIDs[0] * bins.width;
    bounds.max_x = bins.min + sideIDs[1] * bins.width;
    bounds.max_y = 1.5 * maxCount;
    return bounds;
}

unittest
{
    Bins!size_t bins;
    bins.min = -1;
    bins.width = 0.5;
    bins.mybins = [1, 3, 4, 1];
    auto bounds = bins.optimalBounds;
    assert(bounds == Bounds(-1, 1, 0, 6));
    bins.mybins = [0, 0, 4, 0];
    bounds = bins.optimalBounds;
    assert(bounds == Bounds(0, 0.5, 0, 6));
    bins.mybins = [2, 0, 4, 0];
    bounds = bins.optimalBounds;
    assert(bounds == Bounds(-1, 0.5, 0, 6));
}

Bins!T toBins(T : size_t, R)(R range, size_t noBins = 4)
{
    Bins!T bins;
    // Should work, but for some reason plotcli compilation throws an error
    auto r = range.reduce!(min, max);
    bins.min = r[0];
    double max = r[1];
    bins.length = noBins;
    bins.width = 0.5;
    if (bins.min != max)
        
        // Slightly bigger so we include max value as well
        bins.width = (1 + 1e-5) * (max - bins.min) / bins.length;
    // add all data to bin
    foreach (data; range)
        bins = bins.addDataToBin([bins.binId(data)]);
    return bins;
}

;
unittest
{
    auto bins = [1, 2, 3, 3.1, 4].toBins!size_t(2);
    assert(bins.min == 1);
    assert(bins.max >= 4);
    assert(equal(bins.mybins, [2, 3]));
}

private Bins!T emptyBins(T : size_t)(double[] mins, double[] maxs, size_t noBins)
{
    Bins!T bins;
    bins.min = mins[0];
    bins.length = noBins;
    bins.width = 0.5;
    if (bins.min != maxs[0])
        
        // Slightly bigger so we include max value as well
        bins.width = (1 + 1e-5) * (maxs[0] - bins.min) / bins.length;
    return bins;
}

private Bins!T emptyBins(T)(double[] mins, double[] maxs, size_t noBins)
{
    Bins!T bins;
    bins.min = mins[0];
    bins.length = noBins;
    bins.width = 0.5;
    if (bins.min != maxs[0])
        
        // Slightly bigger so we include max value as well
        bins.width = (1 + 1e-5) * (maxs[0] - bins.min) / bins.length;
    foreach (i; 0 .. noBins)
    {
        static if (is(T t == Bins!U, U))
        {
            bins.mybins[i] = emptyBins!U(mins[1 .. $], maxs[1 .. $], noBins);
        }
        else
        {
            bins.mybins[i] = emptyBins!size_t(mins[1 .. $], maxs[1 .. $], noBins);
        }
    }
    return bins;
}

unittest
{
    auto bins = emptyBins!(Bins!size_t)([0.1, 1], [2.1, 3], 4);
    assert(bins.min == 0.1);
    assert(bins[0].min == 1);
    auto bins2 = emptyBins!(Bins!(Bins!size_t))([0.1, 1, 2], [2.1, 3, 2.5], 4);
    assert(bins2.min == 0.1);
    assert(bins2[0].min == 1);
    assert(bins2[0].mybins[0].min == 2);
}

Bins!T toBins(T, R)(R range, size_t noBins = 4)
{
    double[] mins = range[0].dup;
    double[] maxs = range[0].dup;
    if (range.length > 1)
    {
        foreach (row; range[1 .. $])
        {
            foreach (i; 0 .. row.length)
            {
                if (row[i] < mins[i])
                {
                    mins[i] = row[i];
                }
                else if (row[i] > maxs[i])
                    maxs[i] = row[i];
            }
        }
    }
    auto bins = emptyBins!T(mins, maxs, noBins);
    // add all data to bin
    foreach (data; range)
        bins = bins.addData(data);
    return bins;
}

;
///
unittest
{
    auto bins = [[1.0, 2], [3, 3.1], [4.0, 2]].toBins!(Bins!size_t)(2);
    assert(bins.min == 1);
    assert(bins.max >= 4);
    assert(bins[0].min == 2);
    assert(bins[0].max >= 3.1);
    assert(bins[0].mybins[0] == 1);
    bins = [[1.0, 2]].toBins!(Bins!size_t)(2);
    assert(bins.width == 0.5);
    assert(bins[0].width == 0.5);
}


/**
  Resize the bins

  Again an array in case of resizing multidmensional arrays
 */

/*Bins!T resize( T )( Bins!T bins, const size_t[] new_length ) {
    T default_value;
    assert( bins.mybins.length > 0, 
            "Multidimensional need to have at least one bin to correctly resize" );
    default_value = new T;
    default_value.min = bins.mybins[0].min;
    default_value.width = bins.mybins[0].width;
    while ( bins.mybins.length < new_length[0] )
        bins.mybins ~= [default_value];

    if ( new_length.length > 1 )
        foreach ( ref T bin; bins.mybins )
            bin.resize( new_length[1..$] );

    return bins;
}

Bins!T resize( T : size_t )( Bins!T bins, const size_t[] new_length ) {
    T default_value = 0;

    while ( bins.mybins.length < new_length[0] )
        bins.mybins ~= [default_value];
    return bins;
}

unittest {
    auto bins = new Bins!size_t;
    bins.min = -1;
    bins.width = 0.5;
    bins.mybins = [1,2,3,4];

    bins.resize( [3] );
    assert( bins.length == 4 );
    bins.resize( [6] );
    assert( bins.length == 6 );

    auto mbins = new Bins!(Bins!size_t);
    mbins.min = -1;
    mbins.width = 0.5;
    mbins.mybins = [bins, bins.dup];
    mbins.resize( [6] );
    assert( mbins.length == 6 );
    assert( mbins.mybins[5].min == bins.min );
    assert( mbins.mybins[5].width == bins.width );
    mbins.resize( [7,8] );
    assert( mbins.length == 7 );

    foreach( x, bin; mbins )
        assert( bin.length == 8 );
}*/

/**
  Calculate bin id based on data value and Bins
  */

/*size_t bin_id(T)( const Bins!T bins, double data ) {
    assert( data >= bins.min );
    return cast(size_t)( (data-bins.min)/bins.width );
}
unittest {
    auto bins = new Bins!size_t;
    bins.min = -1;
    bins.width = 0.5;
    assert( bin_id( bins, -1 ) == 0 );
    assert( bin_id( bins, -0.5 ) == 1 );
    assert( bin_id( bins, -0.25 ) == 1 );
}*/

/**
  Add data to existing Bins
  */

/*Bins!T addData( T )( Bins!T bins, const double[] data ) {
    size_t[] ids;
    auto bins_step = bins;
    for ( size_t i = 0; i < data.length; i++ ) {
        ids ~= bin_id( bins_step, data[i] );
        if (i < data.length -1)
            bins_step = bins_step.mybins[0];
    }
    return addDataToBin( bins, ids.reverse );
}

Bins!T addData( T : size_t )( Bins!T bins, const double[] data ) {
    return addDataToBin( bins, [bin_id( bins, data[0] )] );
}

unittest {
    auto bins = new Bins!size_t;
    bins.min = -1;
    bins.width = 0.5;
    bins.max_size = 4;
    bins.mybins = [1,2,3,4];

    bins = bins.addData( [-0.25] );
    assert( bins.mybins[1] == 3 );
    bins = addData( bins, [0.75] );
    assert( bins.mybins[3] == 5 );
    assert( bins.max_size == 5 );

    auto mbins = new Bins!(Bins!size_t);
    mbins.min = -1;
    mbins.width = 0.5;
    mbins.mybins = [bins, bins.dup];
    mbins.max_size = 5;
    mbins.addDataToBin( [1,2] );
    assert( mbins.mybins[1].mybins[2] == 4 );
    mbins.addDataToBin( [1,3] );
    assert( mbins.mybins[1].mybins[3] == 6 );
    assert( mbins.max_size == 6 );
}*/
