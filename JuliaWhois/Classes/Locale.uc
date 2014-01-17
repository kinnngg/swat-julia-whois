class Locale extends Julia.Locale;

/**
 * Copyright (c) 2014 Sergei Khoroshilov <kh.sergei@gmail.com>
 * 
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 * 
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 * 
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

var config string WhoisCommandUsage;
var config string WhoisCommandDescription;
var config string WhoisCommandNoMatchError;

var config string CustomCommandUsage;
var config string CustomCommandDescription;
var config string CustomCommandLengthError;

defaultproperties
{
    WhoisCommandUsage="!%1 name";
    WhoisCommandDescription="Displays player details.\\nName may contain wildcard characters.";
    WhoisCommandNoMatchError="No player matching the criteria has been found.\\nPlease provide a more specific name.";

    CustomCommandUsage="!%1 arguments";
    CustomCommandDescription="Performs a whois lookup with arbitrary arguments.";
    CustomCommandLengthError="Please try a shorter criteria.";
}

/* vim: set ft=java: */