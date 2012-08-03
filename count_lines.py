#!/usr/bin/python
#encoding=utf-8
import os, os.path

g_suffix = ['.h', '.c', '.cpp', '.py', '.rkt', '.ss', '.asm', 'java']
g_exclusive_dir = ['我的资料', '多核计算', 'Python-2.5.5',
                   'TBB_source', '徐会涛', 'debug',
                   'C++ Primer/Sourcefile', 'C++/stl']
g_dir_len = len(os.getcwd())
g_files_counter = 0
g_lines_counter = 0
g_file = open('lines.txt', 'w')

def IsSourceFile(filename):
 for suffix in g_suffix:
  if filename.endswith(suffix):
   return True
 return False

def CountFileLine(pathname):
 global g_files_counter
 g_files_counter += 1
 file_handle = open(pathname)
 counter = 0
 for line in file_handle:
  counter += 1
 file_handle.close()
 g_file.write('file: %s lines: %d\n' % (pathname[g_dir_len+1:], counter))
 return counter

def IsExcluseDir(dir_name):
 for ex_dir in g_exclusive_dir:
  if ex_dir in dir_name:
   return True
 return False

def CountLine(args, dir_name, files):
 if IsExcluseDir(dir_name):
  return
 global g_lines_counter
 for filename in files:
  if IsSourceFile(filename):
   g_lines_counter += CountFileLine(dir_name + '/' + filename)

os.path.walk(os.getcwd(), CountLine, 0)
print('Lines: %d' % g_lines_counter)
g_file.write('Files: %d\nLines: %d\n' % (g_files_counter, g_lines_counter))
g_file.close()
