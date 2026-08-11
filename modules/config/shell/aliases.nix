{
  # Navigation
  dot = "cd $DOTFILES";
  repos = "cd $REPOS";
  ".." = "cd ..";
  "..." = "cd ../..";
  "...." = "cd ../../..";
  mkdir = "mkdir -pv";

  # eza (modern ls)
  ls = "eza --color=auto --icons=auto";
  la = "eza -la --icons=auto";
  ll = "eza -l --git --hyperlink --icons=auto";
  lt = "eza --tree --level=2 --icons=auto";
  lta = "eza --tree --level=2 --icons=auto -a";
  ltl = "eza --tree --level=2 --icons=auto -l";
  ldir = "eza --long --icons=auto --only-dirs";
  lg = "lazygit";
  lm = "eza --icons=auto --sort=modified";
  lz = "eza --icons=auto --sort=size";
  f = "tv";

  # Applications
  v = "nvim";
  t = "tmux new-session -A -s dev";
  p = "python";
  e = "exit";
  c = "clear";

  # Git
  g = "git";
  ga = "git add";
  gc = "git commit";
  gcm = "git commit -m";
  gco = "git checkout";
  gd = "git diff";
  gl = "git log";
  gp = "git pull";
  gP = "git push";
  gs = "git status";

  # Container
  d = "docker";
  dc = "docker-compose";
  ld = "lazydocker";
  lss = "lazyssh";
  lssh = "lazyssh";
  dru = "docker run -it --rm -v ~/repos/personal/nixconf:/root/nixconf ubuntu bash";

  # GitLab (glab CLI)
  gm = "glab mr";
  gml = "glab mr list";
  gmv = "glab mr view";
  gmc = "glab mr create";
  gma = "glab mr approve";
  gmm = "glab mr merge";
  gci = "glab ci";
  gcil = "glab ci list";
  gciv = "glab ci view";

  # DevPod
  ds = "devpod ssh";
  du = "devpod up .";

  # Password Manager (pass)
  pw = "pass";
  pwls = "pass ls";
  pwgen = "pass generate";
  pwcp = "pass show -c";
}
