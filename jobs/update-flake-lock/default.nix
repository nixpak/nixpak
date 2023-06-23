{
  hercules-ci.flake-update = {
    enable = true;
    createPullRequest = true;
    autoMergeMethod = "merge";
    forgeType = "github";
    updateBranch = "pr-flake-update";
    when = {
      dayOfWeek = "Thu";
      hour = 2;
    };
  };
}
