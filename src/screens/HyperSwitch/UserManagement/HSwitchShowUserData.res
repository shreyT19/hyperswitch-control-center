open HSwitchUserManagementUtils

external typeConversion: array<Js.Nullable.t<HSwitchUserRoleEntity.userTableTypes>> => array<
  HSwitchUserRoleEntity.userTableTypes,
> = "%identity"

module UserHeading = {
  @react.component
  let make = (~infoValue: HSwitchUserRoleEntity.userTableTypes, ~userId) => {
    open APIUtils
    let showToast = ToastState.useShowToast()
    let updateDetails = useUpdateMethod()
    let status = infoValue.status->HSwitchUserRoleEntity.statusToVariantMapper

    let resendInvite = async () => {
      try {
        let url = getURL(~entityName=USERS, ~userType=#RESEND_INVITE, ~methodType=Post, ())
        let body = [("user_id", userId->Js.Json.string)]->Js.Dict.fromArray->Js.Json.object_
        let _ = await updateDetails(url, body, Post)
        showToast(~message=`Invite resend. Please check your email.`, ~toastType=ToastSuccess, ())
      } catch {
      | _ => ()
      }
    }

    <div className="flex justify-between flex-wrap">
      <PageUtils.PageHeading
        title=infoValue.name
        subTitle=infoValue.email
        customTitleStyle="!p-0"
        isTag=true
        tagText={infoValue.role_name->Js.String2.toUpperCase}
      />
      <div className="flex items-center gap-4">
        <div className={`font-semibold text-green-700`}>
          {switch status {
          | InviteSent => "INVITE SENT"->Js.String2.toUpperCase->React.string
          | _ => infoValue.status->Js.String2.toUpperCase->React.string
          }}
        </div>
        <UIUtils.RenderIf condition={status !== Active}>
          <Button
            text="Resend Invite"
            buttonType={SecondaryFilled}
            customButtonStyle="!px-2"
            onClick={_ => resendInvite()->ignore}
          />
        </UIUtils.RenderIf>
      </div>
    </div>
  }
}

@react.component
let make = () => {
  open APIUtils
  let fetchDetails = useGetMethod()
  let url = RescriptReactRouter.useUrl()
  let (roleData, setRoleData) = React.useState(_ => Js.Json.null)
  let {permissionInfo, setPermissionInfo} = React.useContext(GlobalProvider.defaultContext)
  let (screenState, setScreenState) = React.useState(_ => PageLoaderWrapper.Loading)
  let (usersList, setUsersList) = React.useState(_ => [])

  let currentSelectedUser = React.useMemo1(() => {
    usersList
    ->typeConversion
    ->Array.reduce(Js.Dict.empty()->HSwitchUserRoleEntity.itemToObjMapperForUser, (acc, ele) => {
      url.path->Belt.List.toArray->Js.Array2.joinWith("/")->Js.String2.includes(ele.user_id)
        ? ele
        : acc
    })
  }, [usersList])

  let getRoleForUser = async () => {
    try {
      // TODO - Temp fix - Backend fix awaited
      let url = getURL(
        ~entityName=USER_MANAGEMENT,
        ~userRoleTypes=ROLE_ID,
        ~id={
          Some(
            currentSelectedUser.role_id === "org_admin"
              ? "merchant_admin"
              : currentSelectedUser.role_id,
          )
        },
        ~methodType=Get,
        (),
      )
      let res = await fetchDetails(url)
      setRoleData(_ => res)
      await HyperSwitchUtils.delay(300)
      setScreenState(_ => PageLoaderWrapper.Success)
    } catch {
    | Js.Exn.Error(e) =>
      let err = Js.Exn.message(e)->Belt.Option.getWithDefault("Failed to Fetch!")
      setScreenState(_ => PageLoaderWrapper.Error(err))
    }
  }

  let getPermissionInfo = async () => {
    try {
      let url = getURL(~entityName=USERS, ~userType=#PERMISSION_INFO, ~methodType=Get, ())
      let res = await fetchDetails(url)
      let permissionInfoValue =
        res->LogicUtils.getArrayDataFromJson(ProviderHelper.itemToObjMapperForGetInfo)
      setPermissionInfo(_ => permissionInfoValue)
      if currentSelectedUser.role_id->Js.String2.length !== 0 {
        getRoleForUser()->ignore
      }
    } catch {
    | _ => ()
    }
  }

  let getUserData = async () => {
    try {
      let userDataURL = getURL(
        ~entityName=USER_MANAGEMENT,
        ~methodType=Get,
        ~userRoleTypes=USER_LIST,
        (),
      )
      let res = await fetchDetails(userDataURL)
      let userData =
        res->LogicUtils.getArrayDataFromJson(HSwitchUserRoleEntity.itemToObjMapperForUser)
      setUsersList(_ => userData->Js.Array2.map(Js.Nullable.return))
    } catch {
    | _ => ()
    }
  }

  React.useEffect1(() => {
    if usersList->Js.Array2.length === 0 {
      getUserData()->ignore
    }
    if permissionInfo->Js.Array2.length === 0 {
      getPermissionInfo()->ignore
    } else if currentSelectedUser.role_id->Js.String2.length !== 0 {
      getRoleForUser()->ignore
    }
    None
  }, [currentSelectedUser])

  React.useEffect1(() => {
    let defaultList = defaultPresentInInfoList(permissionInfo)
    setPermissionInfo(_ => defaultList)
    let updatedPermissionListForGivenRole = updatePresentInInfoList(
      defaultList,
      roleData->getArrayOfPermissionData,
    )
    setPermissionInfo(_ => updatedPermissionListForGivenRole)

    None
  }, [roleData])

  <PageLoaderWrapper screenState>
    <div className="h-full">
      <BreadCrumbNavigation
        path=[{title: "Users", link: "/users"}] currentPageTitle=currentSelectedUser.name
      />
      <div className="h-4/5 bg-white mt-5 p-10 relative flex flex-col gap-8">
        <UserHeading infoValue={currentSelectedUser} userId={currentSelectedUser.user_id} />
        <div className="flex flex-col justify-between gap-12 show-scrollbar overflow-scroll">
          {permissionInfo
          ->Array.mapWithIndex((ele, index) => {
            <RolePermissionValueRenderer
              key={index->string_of_int}
              heading={`${ele.module_} module`}
              description={ele.description}
              readWriteValues={ele.permissions}
            />
          })
          ->React.array}
        </div>
      </div>
    </div>
  </PageLoaderWrapper>
}
