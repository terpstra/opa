/*  opa: Open Processor Architecture
 *  Copyright (C) 2014-2016  Wesley W. Terpstra
 *
 *  This program is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 *  To apply the GPL to my VHDL, please follow these definitions:
 *    Program        - The entire collection of VHDL in this project and any
 *                     netlist or floorplan derived from it.
 *    System Library - Any macro that translates directly to hardware
 *                     e.g. registers, IO pins, or memory blocks
 *    
 *  My intent is that if you include OPA into your project, all of the HDL
 *  and other design files that go into the same physical chip must also
 *  be released under the GPL. If this does not cover your usage, then you
 *  must consult me directly to receive the code under a different license.
*/

`timescale 1ns/10ps
module  pll(
	input wire refclk,
	input wire rst,
	output wire outclk_0,
	output wire locked
);

	altera_pll #(
		.fractional_vco_multiplier("false"),
		.reference_clock_frequency("50.0 MHz"),
		.operation_mode("normal"),
		.number_of_clocks(1),
		.output_clock_frequency0("100.000000 MHz"),
		.phase_shift0("0 ps"),
		.duty_cycle0(50),
		.pll_type("General"),
		.pll_subtype("General")
	) altera_pll_i (
		.rst	(rst),
		.outclk	({outclk_0}),
		.locked	(locked),
		.fboutclk	( ),
		.fbclk	(1'b0),
		.refclk	(refclk)
	);

endmodule
