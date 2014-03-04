class String
  def git_option_path_split
    section, *subsection, option = split('.')
    [section, subsection.join('.'), option]
  end
end
