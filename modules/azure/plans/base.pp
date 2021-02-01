plan azure::base (
  TargetSpec $targets,
  Optional[String] $action = 'apply'
){
  if ($action == 'apply'){

    run_plan('azure::tfapply', $targets)

    run_plan('azure::agentinst')

  }

  if ($action == 'destroy'){

    run_plan('azure::tfdestroy', $targets)

  }

}
