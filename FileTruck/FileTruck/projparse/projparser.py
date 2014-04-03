#!/usr/bin/python

import re
import sys

class Entry:
	""" a soft link/forward declaration to a section """
	def __init__(self, id, name):
		self.id = id
		self.name = name
		self.parent = None

	def is_file(self):
		return False

	def set_parent(self, parent):
		self.parent = parent

	def visit(self, fn, depth):
		fn(self, depth)

class FileReference(Entry):
	def __init__(self, id, name, path, location):
		Entry.__init__(self, id, name)
		self.path = path
		self.location = location

	def is_file(self):
		return True

class Link(Entry):
	pass

class Section(Entry):
	""" a proper section from the project file """

	def __init__(self, id, name):
		Entry.__init__(self, id, name)
		self.children = {}
		self.location = None

	def add_link(self, link):
		""" add a soft link / forward declaration to a section """
		self.children[link.id] = link

	def link_to_child(self, child):
		""" replaces the soft link with a proper section """
		self.add_link(child)

	def visit(self, fn, depth):
		Entry.visit(self, fn, depth)
		for child in self.children.values():
			child.visit(fn, depth + 1)

def parse_proj(lines):
	""" parse a project file, looking for section definitions """

	section_regex_start = re.compile(
			'\s*([0-9A-F]+) /\* ([^*]+) \*/ = {$', re.I)

	section_regex_end = re.compile('\s*};$')

	children_regex = re.compile('\s*([0-9A-F]+) /\* ([^*]+) \*/,', re.I)
	children_regex_start = re.compile('\s*children = \(')
	children_regex_end = re.compile('\s*\);')
	group_regex = re.compile('\s*sourceTree = ([^;]+);')

	file_reference_regex = re.compile(
			'\s*([0-9A-F]+) /\* ([^*]+) \*/ = .* ' +
			'path = ([^;]+); sourceTree = ([^;]+);',
			re.I)

	entries = {}
	current_section = None
	got_children = False

	for line in lines:
		if current_section:
			end = section_regex_end.match(line)
			if end:
				current_section = None
				continue

			# look for the children marker, or append to children
			if got_children:
				if children_regex_end.match(line):
					got_children = False
				else:
					child_match = children_regex.match(line)
					if child_match:
						id = child_match.groups()[0]
						name = child_match.groups()[1]
						current_section.add_link(Link(id, name))

			elif children_regex_start.match(line):
				got_children = True

			else:
				# no children, try to match a sourceTree = ...; line
				group = group_regex.match(line)
				if group:
					current_section.location = group.groups()[0]


		else:
			# try for a new section
			new_section_matches = section_regex_start.match(line)

			if new_section_matches:
				id = new_section_matches.groups()[0]
				name = new_section_matches.groups()[1]

				current_section = Section(id, name)
				entries[id] = current_section
			else:
				# no new section, check for a plain FileReference
				file_ref_captures = file_reference_regex.match(line)
				if file_ref_captures:
					id = file_ref_captures.groups()[0]
					name = file_ref_captures.groups()[1]
					path = file_ref_captures.groups()[2]
					location = file_ref_captures.groups()[3]
					entries[id] = FileReference(id, name, path, location)

	return entries


def link_entries(entries):
	""" link entries to 'Section' back references, and
	file references into sections """

	for id in entries.keys():
		entry = entries[id]

		if entry.is_file():
			continue

		for child_id in entry.children.keys():
			# for each of this entry's children, see if it
			# exists in the main entry map:
			if entries.has_key(child_id):
				# replace the soft link with a real entry
				proper_child = entries[child_id]
				proper_child.set_parent(entry)
				entry.link_to_child(proper_child)

	return entries


def parse(lines):
	# parse and convert soft links to hard references to other sections
	entries = parse_proj(lines)
	entries = link_entries(entries)

	# find the top-level parents
	top_level_sections = []
	for id in entries.keys():
		candidate = entries[id]
		if not candidate.parent and not candidate.is_file():
			top_level_sections.append(candidate)

	return top_level_sections
