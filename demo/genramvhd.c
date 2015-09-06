/*
 * This work is part of the White Rabbit project
 *
 * Copyright (C) 2012 GSI (www.gsi.de)
 * Author: Wesley W. Terpstra <w.terpstra@gsi.de>
 *
 * Released according to the GNU GPL, version 2 or any later version.
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <math.h>
#include <unistd.h>		/* getopt */

const char *program;
const char *package;
const char *filename;
long width;
int bigendian;
int verbose;

void help()
{
	fprintf(stderr, "Usage: %s [OPTION] <filename>\n", program);
	fprintf(stderr, "\n");
	fprintf(stderr,
		"  -w <width>     width of values in bytes [1/2/4/8/16]        (4)\n");
	fprintf(stderr,
		"  -p <package>   name of the output package            (filename)\n");
	fprintf(stderr,
		"  -s <size>      pad the output up to size bytes       (filesize)\n");
	fprintf(stderr,
		"  -b             big-endian operation                         (*)\n");
	fprintf(stderr,
		"  -l             little-endian operation                         \n");
	fprintf(stderr, "  -v             verbose operation\n");
	fprintf(stderr, "  -h             display this help and exit\n");
	fprintf(stderr, "\n");
	fprintf(stderr,
		"Report Etherbone bugs to <white-rabbit-dev@ohwr.org>\n");
}

/* We don't want localized versions from ctype.h */
static int my_isalpha(char c)
{
	return (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z');
}

static int my_isok(char c)
{
	return c == '_' || my_isalpha(c) || (c >= '0' && c <= '9');
}

int main(int argc, char **argv)
{
	int j, opt, error, i_width;
	long i, elements, size, columns, entry_width;
	char *value_end;
	unsigned char x[16];	/* Up to 128 bit */
	char buf[100];
	FILE *f;

	/* Default values */
	program = argv[0];
	package = 0;		/* auto-detect */
	width = 4;
	bigendian = 1;
	verbose = 0;
	size = -1;		/* file size */
	error = 0;

	/* Process the command-line */
	while ((opt = getopt(argc, argv, "w:p:s:blvh")) != -1) {
		switch (opt) {
		case 'w':
			width = strtol(optarg, &value_end, 0);
			if (*value_end ||	/* bad integer */
			    ((width - 1) & width) != 0 ||	/* not a power of 2 */
			    width == 0 || width > 16) {
				fprintf(stderr,
					"%s: invalid value width -- '%s'\n",
					program, optarg);
				error = 1;
			}
			break;
		case 'p':
			package = optarg;
			break;
		case 's':
			size = strtol(optarg, &value_end, 0);
			if (*value_end) {
				fprintf(stderr,
					"%s: invalid value size -- '%s'\n",
					program, optarg);
				error = 1;
			}
			break;
		case 'b':
			bigendian = 1;
			break;
		case 'l':
			bigendian = 0;
			break;
		case 'v':
			verbose = 1;
			break;
		case 'h':
			help();
			return 1;
		case ':':
		case '?':
			error = 1;
			break;
		default:
			fprintf(stderr, "%s: bad getopt result\n", program);
			return 1;
		}
	}

	if (error) return 1;
	if (optind + 1 != argc) {
		fprintf(stderr,
			"%s: expecting one non-optional argument: <filename>\n",
			program);
		return 1;
	}

	filename = argv[optind];

	/* Confirm the filename exists */
	if ((f = fopen(filename, "r")) == 0) {
		fprintf(stderr, "%s: %s while opening '%s'\n", program,
			strerror(errno), filename);
		return 1;
	}

	/* Deduce if it's aligned */
	fseek(f, 0, SEEK_END);
	elements = ftell(f);
	rewind(f);

	if (size == -1) {
		size = elements;
	}

	if (size < elements) {
		fprintf(stderr,
			"%s: length of initialization file '%s' (%ld) exceeds specified size (%ld)\n",
			program, filename, elements, size);
		return 1;
	}

	if (elements % width != 0) {
		fprintf(stderr,
			"%s: initialization file '%s' is not a multiple of %ld bytes\n",
			program, filename, width);
		return 1;
	}
	elements /= width;

	if (size % width != 0) {
		fprintf(stderr,
			"%s: specified size '%ld' is not a multiple of %ld bytes\n",
			program, size, width);
		return 1;
	}
	size /= width;

	/* Find a suitable package name */
	if (package == 0) {
		if (strlen(filename) >= sizeof(buf) - 5) {
			fprintf(stderr,
				"%s: filename too long to deduce package name -- '%s'\n",
				program, filename);
			return 1;
		}

		/* Find the first alpha character */
		while (*filename && !my_isalpha(*filename))
			++filename;

		/* Start copying the filename to the package */
		for (i = 0; filename[i]; ++i) {
			if (my_isok(filename[i]))
				buf[i] = filename[i];
			else
				buf[i] = '_';
		}
		buf[i] = 0;

		if (i == 0) {
			fprintf(stderr,
				"%s: no appropriate characters in filename to use for package name -- '%s'\n",
				program, filename);
			return 1;
		}

		package = &buf[0];
	} else {
		/* Check for valid VHDL identifier */
		if (!my_isalpha(package[0])) {
			fprintf(stderr, "%s: invalid package name -- '%s'\n",
				program, package);
			return 1;
		}
		for (i = 1; package[i]; ++i) {
			if (!my_isok(package[i])) {
				fprintf(stderr,
					"%s: invalid package name -- '%s'\n",
					program, package);
				return 1;
			}
		}
	}

	/* Find how many digits it takes to fit 'size' */
	i_width = 1;
	for (i = 10; i <= size; i *= 10)
		++i_width;

	/* How wide is an entry of the table? */
	entry_width = i_width + 6 + width * 2 + 3;
	columns = 76 / entry_width;

	printf("-- AUTOGENERATED FILE (from genramvhd.c run on %s) --\n", filename);
	printf("library ieee;\n");
	printf("use ieee.std_logic_1164.all;\n");
	printf("use ieee.numeric_std.all;\n");
	printf("\n");

	printf("package %s_pkg is\n", package);
	printf("  type t_word_array is array(natural range <>) of std_logic_vector(%ld downto 0);\n", (width*8)-1);
	printf("  constant %s : t_word_array(%ld downto 0) := (\n", package, size - 1);

	for (i = 0; i < size; ++i) {
		if (i % columns == 0)
			printf("    ");

		if (i < elements) {
			if (fread(x, 1, width, f) != width) {
				perror("fread");
				return 1;
			}
		} else {
			memset(x, 0, sizeof(x));
		}

		printf("%*ld => x\"", i_width, i);
		if (bigendian) {
			for (j = 0; j < width; ++j)
				printf("%02x", x[j]);
		} else {
			for (j = width - 1; j >= 0; --j)
				printf("%02x", x[j]);
		}
		printf("\"");

		if ((i + 1) == size)
			printf(");\n");
		else if ((i + 1) % columns == 0)
			printf(",\n");
		else
			printf(", ");
	}
	fclose(f);

	printf("end %s_pkg;\n", package);

	return 0;
}
