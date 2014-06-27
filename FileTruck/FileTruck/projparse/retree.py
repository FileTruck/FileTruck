#!/usr/bin/python

import fileinput
import sys
import os
import re
import errno

import projparser

class Unimplemented(Exception):
	pass

def read_file(fname):
	return [line for line in fileinput.input([fname])]

def write_file(fname, lines):
	with open(fname, 'w') as f:
		for line in lines:
			if len(line):
				f.write(line)

def get_entries(path):
	try:
		lines = read_file(path)
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


# path methods
def path_for_groups(entry):
	path = ''
	parent = entry.parent
	while parent is not None:
		path = parent.name + '/' + path
		parent = parent.parent
	return path

def top_level_section(entry):
	parent = entry.parent
	while parent.parent:
		parent = parent.parent
	return parent

# location handlers

def location_absolute(entry, projdir):
	# need to return the full path of entry
	raise Unimplemented()

def location_group(entry, projdir):
	# need to walk up entry's parents building a path
	path = path_for_groups(entry)
	# root at the project file
	return projdir + '/../' + path

def location_srcroot(entry, projdir):
	# relative to .xcodeproj - need to do some path wrangling
	raise Unimplemented()

def location_dev_dir(entry, projdir):
	raise Unimplemented()

def location_built_dir(entry, projdir):
	raise Unimplemented()

def location_sdkroot(entry, projdir):
	raise Unimplemented()

locations = {
	'"<absolute>"': location_absolute,
	'"<group>"': location_group,
	"SOURCE_ROOT": location_srcroot,
	"DEVELOPER_DIR": location_dev_dir,
	"BUILT_PRODUCTS_DIR": location_built_dir,
	"SDKROOT": location_sdkroot,
}

def construct_dir_for_entry(entry, projpath):
	""" returns a /-terminated path """
	assert entry.location is not None
	return locations[entry.location](entry, os.path.dirname(projpath))

def quote(path):
	return "'" + path + "'"

def mkdir_p(dir):
	try:
		os.makedirs(dir)
	except OSError as e:
		if e.errno == errno.EEXIST:
			# this is fine
			return
		# otherwise rethrow
		raise


def move_file(entry, to_dir, projpath):
	global settings

	top_level = top_level_section(entry)
	old_fname = projpath + '/../' + top_level.name + '/' + entry.path

	new_fname = to_dir + '/' + entry.name

	mkdir_p(to_dir)

	ret_code = os.system(
			settings.move_cmd + \
					" " + \
					quote(old_fname) + \
					" " + \
					quote(new_fname))

	if ret_code != 0:
		print >>sys.stderr, \
				"couldn't rename " + \
				old_fname + \
				" (returned  " + str(ret_code) + ")"
		return


def project_file_update(entry, to_dir, rewrites):
	# TODO dispatch based on type, e.g. "<group>"

	path = os.path.normpath(to_dir + '/' + entry.name)
	# strip top level, since we've assumed "<group>"
	path = '/'.join( path.split('/')[1:] )

	rewrites.append({
		'id': entry.id,
		'path': path
	})

def ignore_entry(entry):
	framework = 'framework'

	# take a slice from end-len(framework) to the end:
	slice = entry.name[-len(framework):]

	return slice == framework


def reorder_section(section, rewrites, projpath):
	def rename_file(entry, rewrites):
		global settings

		try:
			new_path = construct_dir_for_entry(entry, projpath)
		except:
			print >>sys.stderr, "can't move %s - unimplemented" % entry.name
			return

		if settings.rename:
			move_file(entry, new_path, os.path.dirname(projpath))
		if settings.rewrite_projfile:
			project_file_update(entry, new_path, rewrites)

	for child_key in section.children.keys():
		child = section.children[child_key]
		if child.is_file():
			if ignore_entry(child):
				print >>sys.stderr, "ignoring %s" % child.name
			else:
				rename_file(child, rewrites)
		else:
			reorder_section(child, rewrites, projpath)

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
				# if there's no "name = ...;" and the path has a '/' then we need to make one
				# since Xcode uses the path if there's no name
				name_to_insert = ''
				new_path = rewrite['path']
				if line.find('name =') == -1 and new_path.find('/'):
					name_to_insert = "name = '" + new_path.split('/')[-1] + "';"

				index = line_and_idx[1]
				lines[index] = matched.groups()[0] + \
						name_to_insert + \
						'path = "' + new_path + '";' + \
						matched.groups()[1] + "\n"
				break

	write_file(proj_path, lines)

def filesort(argv):
	if len(argv) != 1:
		usage()

	print "parsing projfile..."
	projpath = argv[0]

	sections_and_files = get_entries(projpath)
	rewrites = []

	print "reordering files..."
	for section in sections_and_files:
		reorder_section(section, rewrites, projpath)

	print "rewriting projfile..."
	rewrite_projfile(projpath, rewrites)

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
settings.move_cmd = 'mv'

args = sys.argv[1:]

if len(args) > 0 and args[0] == '--git':
	settings.move_cmd = 'git mv'
	args = args[1:] # shift args

if len(args) == 0:
	usage()

if commands.has_key(args[0]):
	commands[args[0]]["fn"](args[1:])
else:
	usage()
