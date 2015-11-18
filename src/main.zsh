
ORIG_IFS=${IFS}
IFS='#########################'

. ./lib/utils.zsh
. ./lib/workflow.zsh


BIN=$1
QUERY=$2

XPATH_RECENT_PROJECT_DIRECTORIES="//component[@name='RecentDirectoryProjectsManager']/option[@name='recentPaths']/list/option/@value"
XPATH_RECENT_PROJECTS="//component[@name='RecentProjectsManager']/option[@name='recentPaths']/list/option/@value"

##
 # Retrieve project name from project configuration
 #  search project name in this file because project name can be different than folder name
 #   ex: folder: my-project ; project name: My Private Project
 #
 # @param $1 string (path to project)
 # @return string
extractProjectName()
{
    nameFile="$1/.idea/.name"
    if [[ -r ${nameFile} ]]; then
        projectName=`cat ${nameFile}`
        echo ${projectName}
    fi
}

##
 # Retrieve project from PhpStorm configuration
 #  return a string with paths separate by a ;
 #
 # @return string
getProjectsPath()
{
    escapedHome=`echo $HOME | sed -e 's/[/]/\\\\\//g'`

    basePath=`grep -F -m 1 'CONFIG_PATH =' ${BIN}`
    basePath="${basePath#*\'}"
    basePath="${basePath%\'*}"

    recentProjectDirectories="${basePath}/options/recentProjectDirectories.xml"
    recentProjects="${basePath}/options/recentProjects.xml"

    projectsPath=''

    if [[ -r ${recentProjectDirectories} ]]; then
        projectsPath=`xmllint --xpath ${XPATH_RECENT_PROJECT_DIRECTORIES} ${recentProjectDirectories}`
    elif [[ -r ${recentProjects} ]]; then # Intellij Idea
        projectsPath=`xmllint --xpath ${XPATH_RECENT_PROJECTS} ${recentProjects} 2>/dev/null`
    fi

    if [[ -n ${projectsPath} ]]; then
        projectsPath=`echo ${projectsPath} | sed -e 's/key=//g' -e 's/value=//g' -e 's/" "/"\n"/g' -e 's/^ *//g' -e 's/ *$//g' -e 's/"//g' -e "s/[$]USER_HOME[$]/${escapedHome}/g"`
    fi

    echo ${projectsPath}
}

##
 # Entry point
 #
 # @return string (XML for Alfred)
findProject()
{
    # Add test before run search
    appPath=`getAppPath ${BIN}`
    if [[ -z ${appPath} ]]; then
        addItem 'error' '' "Can't find command line launcher for '${BIN}'" "Create/Update command line launcher in Tools > Create Command-line Launcher" 'AlertCautionIcon.icns' 'yes' ''
    else
        # Check if some projects exists
        projectsPath=`getProjectsPath`
        if [[ -z ${projectsPath} ]]; then
            addItem 'none' '' "Can't find projects" "check configuration or contact developer" `getAppIcon ${BIN}` 'yes' ''
        else
            # Search
            nbProject=0

            for projectPath in "${(@f)projectsPath}"; do
                projectName=`extractProjectName ${projectPath}`
                if [[ -n "${projectName}" ]] && [[ "${projectName}" != "" ]]; then
                    matchName=`echo "${projectName}" | grep -i "${QUERY}" | wc -l`
                    matchPath=`echo "${projectPath##*/}" | grep -i "${QUERY}" | wc -l`

                    if ([[ "${matchName}" -eq 1 ]] || [[ "${matchPath}" -eq 1 ]]) || [[ -z "${QUERY}" ]]; then
                        addItem ${projectName} "${BIN}||${projectPath}" ${projectName} ${projectPath} `getAppIcon ${BIN}` 'yes' ${projectName}
                        ((nbProject++))
                    fi
                fi
            done

            # if there is no project display information
            if [[ ${nbProject} -eq 0 ]]; then
                addItem 'none' '' "No project match '${QUERY}'" "No project match '${QUERY}'" `getAppIcon ${BIN}` 'yes' ${QUERY}
            fi
        fi
    fi

    # Render XML
    getItemsXml
}

findProject

IFS=${ORIG_IFS}