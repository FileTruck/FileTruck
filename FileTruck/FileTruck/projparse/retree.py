#!/usr/bin/python

import fileinput
import sys
import os
import re

import projparser

def read_file(fname):
	return [line for line in fileinput.input([fname])]

def write_file(fname, lines):
	with open(fname, 'w') as f:
		for line in lines:
			if len(line):
				f.write(line)

def get_entries(argv):
	try:
		lines = read_file(argv[0])
	except Exception as e:
		print >>sys.stderr, e
		sys.exit(1)
	return projparser.parse(lines)

def listproj(argv):
	if len(argv) != 1:
		usage()

	entries = get_entries(argv)

	for ent in entries:
		if not ent.is_file():
			print ent.name

def full_listproj(argv):
	if len(argv) != 1:
		usage()

	def entry_print(ent, nest):
		sys.stdout.write(' ' * nest)

		location_extra = ''
		if ent.location is not None:
			location_extra = ' (location=%s)' % ent.location
		print "%s (%s)%s" % (ent.name, ent.id, location_extra)

	for ent in get_entries(argv):
		ent.visit(entry_print, 0)

def move_file(entry, to_dir):
	fname = entry.path
	new_fname = to_dir + "/" + fname

	# try git
	ret_code = os.system("git mv '" + fname + "' '" + new_fname + "'")
	if ret_code != 0:
		# didn't work, normal move
		ret_code = os.system("mv '" + fname + "' '" + new_fname + "'")
		if ret_code != 0:
			print >>sys.stderr, "couldn't rename " + fname + ": " + str(ret_code)
			return


def project_file_update(entry, to_dir, rewrites):
	rewrites.append({
		'id': entry.id,
		'path': to_dir + '/' + entry.name
	})

def reorder_section(section, current_path, rewrites):
	def rename_file(entry, current_path, rewrites):
		global settings

		if settings.rename:
			move_file(entry, current_path)
		if settings.rewrite_projfile:
			project_file_update(entry, current_path, rewrites)

	current_path = current_path + '/' + section.name

	for child_key in section.children.keys():
		child = section.children[child_key]
		if child.is_file():
			rename_file(child, current_path, rewrites)
		else:
			reorder_section(child, current_path, rewrites)

def rewrite_projfile(proj_path, rewrites):
	lines = read_file(proj_path)
	for rewrite in rewrites:
		# find the line with our id
		id_regex = re.compile(
				'(\s*' + rewrite['id'] + ' .*)path = [^;]+;( .*)',
				re.I)

		for line_and_idx in zip(lines, [i for i in range(0, len(lines))]):
			line = line_and_idx[0]
			matched = id_regex.match(line)
			if matched:
				# found - rewrite path=...
				index = line_and_idx[1]
				lines[index] = matched.groups()[0] + \
						'path = "' + rewrite['path'] + '";' + \
						matched.groups()[1] + "\n"
				break

	write_file(proj_path, lines)

def filesort(argv):
	if len(argv) != 1:
		usage()

	print "parsing projfile..."
	sections_and_files = get_entries(argv)

	rewrites = []

	print "reordering files..."
	for section in sections_and_files:
		reorder_section(section, '.', rewrites)

	print "rewriting projfile..."
	rewrite_projfile(argv[0], rewrites)

commands = {
	"list": {
		'fn': listproj,
		'desc': "list: list the top level sections of a project file"
	},
	"full-list": {
		'fn': full_listproj,
		'desc': "full-list: recursively list the project file entries"
	},
	"sort": {
		'fn': filesort,
		'desc': "sort: reorganise files to match the project hierarchy"
	},
}

def usage():
	print >>sys.stderr, "" + \
		"Usage: %s <command> file\n" % sys.argv[0] + \
		"\n" + \
		"where command is one of:"

	for key in commands.keys():
		desc = commands[key]['desc']
		print >>sys.stderr, "  " + desc

	sys.exit(1)


class Settings:
	pass
settings = Settings()
settings.rename = True
settings.rewrite_projfile = True

if len(sys.argv) == 1:
	usage()

if commands.has_key(sys.argv[1]):
	commands[sys.argv[1]]["fn"](sys.argv[2:])
else:
	usage()
