#!/usr/bin/env python3
"""Dependency-free deterministic Xcode project generation."""
import pathlib, hashlib, json, plistlib
root = pathlib.Path(__file__).resolve().parents[1]
objects = {}
def ident(s): return hashlib.sha1(s.encode()).hexdigest()[:24].upper()
def add(key, **data):
    i=ident(key); objects[i]=data; return i
def ref(path, type): return add(path, isa='PBXFileReference', lastKnownFileType=type, path=path, sourceTree='<group>')
def configs(name, extra):
    ids=[]
    for mode in ['Debug','Release']:
        settings={'SWIFT_VERSION':'5.0','SWIFT_ACTIVE_COMPILATION_CONDITIONS':'DEBUG' if mode=='Debug' else '','IPHONEOS_DEPLOYMENT_TARGET':'17.0','SDKROOT':'iphoneos','TARGETED_DEVICE_FAMILY':'2','SWIFT_OPTIMIZATION_LEVEL':'-Onone' if mode=='Debug' else '-O','ENABLE_TESTABILITY':'YES','CODE_SIGN_STYLE':'Automatic','CLANG_ENABLE_MODULES':'YES','SWIFT_STRICT_CONCURRENCY':'minimal', **extra}
        if name == 'HomePad':
            settings['CODE_SIGN_ENTITLEMENTS'] = '$(HOMEVIEWPAD_DEBUG_ENTITLEMENTS)' if mode == 'Debug' else 'HomePad/HomePad.entitlements'
            settings['HOMEVIEWPAD_LOCATION_USAGE'] = 'Show weather for your current city. If location is unavailable, HomeViewPad uses Philadelphia. Approximate coordinates are sent to ' + ('the selected provider, Open-Meteo or Apple Weather.' if mode == 'Debug' else 'Apple Weather.')
        ids.append(add(name+mode,isa='XCBuildConfiguration',name=mode,buildSettings=settings,baseConfigurationReference=ident('Config/Signing.xcconfig')))
    return add(name+'configs',isa='XCConfigurationList',buildConfigurations=ids,defaultConfigurationIsVisible='0',defaultConfigurationName='Release')
signing_ref = ref('Config/Signing.xcconfig', 'text.xcconfig')
products=[]; groups=[]; targets=[]
for name, folder, productType, ext in [('HomePad','HomePad','application','app'),('HomePadTests','HomePadTests','bundle.unit-test','xctest'),('HomePadUITests','HomePadUITests','bundle.ui-testing','xctest')]:
    sources=[]; children=[]
    for file in sorted((root/folder).glob('*.swift')):
        f=ref(file.name,'sourcecode.swift'); children.append(f)
        sources.append(add(name+file.name+'build',isa='PBXBuildFile',fileRef=f))
    # IDs for references must remain unique across groups; filenames here are distinct.
    groups.append(add(folder+'group',isa='PBXGroup',children=children,path=folder,sourceTree='<group>'))
    prod=add(name+'product',isa='PBXFileReference',explicitFileType='wrapper.application' if ext=='app' else 'wrapper.cfbundle',path=name+'.'+ext,sourceTree='BUILT_PRODUCTS_DIR'); products.append(prod)
    phases=[add(name+'sources',isa='PBXSourcesBuildPhase',buildActionMask='2147483647',files=sources,runOnlyForDeploymentPostprocessing='0'),add(name+'frameworks',isa='PBXFrameworksBuildPhase',buildActionMask='2147483647',files=[],runOnlyForDeploymentPostprocessing='0')]
    settings={'PRODUCT_BUNDLE_IDENTIFIER':'org.homepad.personal.'+name.lower(),'PRODUCT_NAME':'$(TARGET_NAME)','GENERATE_INFOPLIST_FILE':'YES'}
    dependencies=[]
    if name=='HomePad':
        settings.update({'PRODUCT_BUNDLE_IDENTIFIER':'$(HOMEVIEWPAD_BUNDLE_IDENTIFIER)','DEVELOPMENT_TEAM':'$(HOMEVIEWPAD_DEVELOPMENT_TEAM)','ASSETCATALOG_COMPILER_APPICON_NAME':'AppIcon','INFOPLIST_FILE':'HomePad/Info.plist','GENERATE_INFOPLIST_FILE':'NO','CODE_SIGN_ENTITLEMENTS':'HomePad/HomePad.entitlements','MARKETING_VERSION':'0.1.0','CURRENT_PROJECT_VERSION':'1','SUPPORTED_PLATFORMS':'iphoneos iphonesimulator','SUPPORTS_MACCATALYST':'NO'})
    else:
        proxy=add(name+'proxy',isa='PBXContainerItemProxy',containerPortal=ident('project'),proxyType='1',remoteGlobalIDString=ident('HomePadtarget'),remoteInfo='HomePad')
        dependencies=[add(name+'dependency',isa='PBXTargetDependency',target=ident('HomePadtarget'),targetProxy=proxy)]
        if name=='HomePadTests': settings.update({'TEST_HOST':'$(BUILT_PRODUCTS_DIR)/HomePad.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/HomePad','BUNDLE_LOADER':'$(TEST_HOST)'})
        else: settings['TEST_TARGET_NAME']='HomePad'
    if name == 'HomePad':
        resourceFiles=[]
        for path, typ in [('Assets.xcassets','folder.assetcatalog'),('PrivacyInfo.xcprivacy','text.xml')]:
            f=ref(path,typ); children.append(f); resourceFiles.append(add(path+'build',isa='PBXBuildFile',fileRef=f))
        phases.append(add(name+'resources',isa='PBXResourcesBuildPhase',buildActionMask='2147483647',files=resourceFiles,runOnlyForDeploymentPostprocessing='0'))
    targets.append(add(name+'target',isa='PBXNativeTarget',buildConfigurationList=configs(name,settings),buildPhases=phases,buildRules=[],dependencies=dependencies,name=name,productName=name,productReference=prod,productType='com.apple.product-type.'+productType))
pg=add('products',isa='PBXGroup',children=products,name='Products',sourceTree='<group>')
main=add('main',isa='PBXGroup',children=groups+[pg,signing_ref],sourceTree='<group>')
add('project',isa='PBXProject',attributes={'LastUpgradeCheck':'2700'},buildConfigurationList=configs('project',{}),compatibilityVersion='Xcode 14.0',developmentRegion='en',hasScannedForEncodings='0',knownRegions=['en','Base'],mainGroup=main,productRefGroup=pg,projectDirPath='',projectRoot='',targets=targets)
def serialize(value):
    if isinstance(value,dict): return '{\n'+''.join(f'{json.dumps(k)} = {serialize(v)};\n' for k,v in value.items())+'}'
    if isinstance(value,list): return '('+','.join(serialize(v) for v in value)+')'
    return json.dumps(value)
p=root/'HomePad.xcodeproj'; p.mkdir(exist_ok=True)
(p/'project.pbxproj').write_text('// !$*UTF8*$!\n'+serialize({'archiveVersion':'1','classes':{},'objectVersion':'56','objects':objects,'rootObject':ident('project')}))
s=p/'xcshareddata/xcschemes'; s.mkdir(parents=True,exist_ok=True)
def buildref(name): return f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{ident(name+"target")}" BuildableName="{name}.{ "app" if name=="HomePad" else "xctest"}" BlueprintName="{name}" ReferencedContainer="container:HomePad.xcodeproj"/>'
(s/'HomePad.xcscheme').write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="2700" version="1.3"><BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{buildref('HomePad')}</BuildActionEntry></BuildActionEntries></BuildAction><TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"><Testables>{''.join('<TestableReference skipped="NO">'+buildref(n)+'</TestableReference>' for n in ['HomePadTests','HomePadUITests'])}</Testables></TestAction><LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">{buildref('HomePad')}</BuildableProductRunnable></LaunchAction><ProfileAction buildConfiguration="Release"><BuildableProductRunnable runnableDebuggingMode="0">{buildref('HomePad')}</BuildableProductRunnable></ProfileAction><AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/></Scheme>''')
info={'CFBundleDisplayName':'HomeViewPad','CFBundleIdentifier':'$(PRODUCT_BUNDLE_IDENTIFIER)','CFBundleExecutable':'$(EXECUTABLE_NAME)','CFBundleName':'$(PRODUCT_NAME)','CFBundlePackageType':'APPL','CFBundleShortVersionString':'$(MARKETING_VERSION)','CFBundleVersion':'$(CURRENT_PROJECT_VERSION)','UILaunchScreen':{},'UIApplicationSceneManifest':{'UIApplicationSupportsMultipleScenes':False},'UISupportedInterfaceOrientations~ipad':['UIInterfaceOrientationPortrait','UIInterfaceOrientationPortraitUpsideDown','UIInterfaceOrientationLandscapeLeft','UIInterfaceOrientationLandscapeRight'],'NSLocationWhenInUseUsageDescription':'$(HOMEVIEWPAD_LOCATION_USAGE)', 'NSMicrophoneUsageDescription':'While foreground standby is dimmed, detect sound levels to wake the display or start a short TrueDepth check. No audio is recorded or uploaded.','NSCameraUsageDescription':'After a sound in standby, briefly check for a nearby face using the front TrueDepth camera. No images or depth data are saved or uploaded.','NSPhotoLibraryUsageDescription':'Display photos from the iPad albums you choose in the HomeViewPad photo widget. HomeViewPad never changes your photo library.','PHPhotoLibraryPreventAutomaticLimitedAccessAlert':True,'NSHomeKitUsageDescription':'HomeViewPad shows your home accessories, runs scenes you select, and displays cameras only when you open them.','NSCalendarsFullAccessUsageDescription':'Show upcoming events on this shared iPad screen only after you opt in.','NSRemindersFullAccessUsageDescription':'Show open reminders on this shared iPad screen only after you opt in.'}
(root/'HomePad/Info.plist').write_bytes(plistlib.dumps(info))
(root/'HomePad/HomePad.entitlements').write_bytes(plistlib.dumps({'com.apple.developer.homekit':True, 'com.apple.developer.weatherkit':True}))

(root/'HomePad/HomePadDebug.entitlements').write_bytes(plistlib.dumps({'com.apple.developer.homekit':True}))
