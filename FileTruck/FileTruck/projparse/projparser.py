#!/usr/bin/python

import re
import sys

class Link:
	""" a soft link/forward declaration to a section """
	def __init__(self, id, name):
		self.id = id
		self.name = name
		self.children = {} # always empty

	def id(self):
		return self.id
	def name(self):
		return self.name

class Section:
	""" a proper section from the project file """
	def __init__(self, id, name):
		self.id = id
		self.name = name
		self.children = {}
		self.parent = None

	def add_link(self, link):
		""" add a soft link / forward declaration to a section """
		self.children[link.id] = link

	def link_to_child(self, child):
		""" replaces the soft link with a proper section """
		self.add_link(child)

	def set_parent(self, parent):
		self.parent = parent


def parse_sections(lines):
	""" parse a project file, looking for section definitions """

	section_regex_start = re.compile(
			'\s*([0-9A-F]+) /\* ([^*]+) \*/ = {$', re.I)

	section_regex_end = re.compile('\s*};$')

	children_regex = re.compile('\s*([0-9A-F]+) /\* ([^*]+) \*/,', re.I)
	children_regex_start = re.compile('\s*children = \(')
	children_regex_end = re.compile('\s*\);')

	sections = {}
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
			# try for a new section
			new_section_matches = section_regex_start.match(line)

			if new_section_matches:
				id = new_section_matches.groups()[0]
				name = new_section_matches.groups()[1]

				current_section = Section(id, name)
				sections[id] = current_section

	return sections


def link_sections(sections):
	""" convert 'Link' sections to 'Section' back references """
	for id in sections.keys():
		section = sections[id]

		for child_id in section.children.keys():
			# for each of this section's children, see if it
			# exists in the main section map:
			if sections.has_key(child_id):
				# replace the soft link with a real section
				proper_child = sections[child_id]
				proper_child.set_parent(section)
				section.link_to_child(proper_child)

	return sections


def dump_section(section, indent = 0):
	""" dump a section recursively """

	sys.stdout.write(' ' * indent)
	print "section %s (%s)" % (section.name, section.id)

	for id in section.children.keys():
		child = section.children[id]
		dump_section(child, indent + 1)

def parse(lines):
	# parse and convert soft links to hard references to other sections
	sections = parse_sections(lines)
	sections = link_sections(sections)

	# find the top-level parents
	top_level_sections = []
	for id in sections.keys():
		candidate = sections[id]
		if not candidate.parent:
			top_level_sections.append(candidate)

	return top_level_sections
