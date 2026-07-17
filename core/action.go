package main

import (
	"encoding/json"
	"fmt"
	"runtime"
	"unsafe"
)

type Action struct {
	Id     string          `json:"id"`
	Method Method          `json:"method"`
	Data   json.RawMessage `json:"data"`
}

func (action Action) decodeData(target interface{}) error {
	if len(action.Data) == 0 || string(action.Data) == "null" {
		return fmt.Errorf("missing data")
	}
	return json.Unmarshal(action.Data, target)
}

func decodeActionData(action *Action, result ActionResult, target interface{}) bool {
	if err := action.decodeData(target); err != nil {
		result.error(fmt.Sprintf("invalid data for %s: %v", action.Method, err))
		return false
	}
	return true
}

type ActionResult struct {
	Id       string      `json:"id"`
	Method   Method      `json:"method"`
	Data     interface{} `json:"data"`
	Code     int         `json:"code"`
	callback unsafe.Pointer
}

func (result ActionResult) Json() ([]byte, error) {
	data, err := json.Marshal(result)
	return data, err
}

func (result ActionResult) success(data interface{}) {
	result.Code = 0
	result.Data = data
	result.send()
}

func (result ActionResult) error(data interface{}) {
	result.Code = -1
	result.Data = data
	result.send()
}

func handleAction(action *Action, result ActionResult) {
	defer func() {
		if r := recover(); r != nil {
			buf := make([]byte, 4096)
			n := runtime.Stack(buf, false)
			logError("panic in handleAction(%s): %v\n%s", action.Method, r, buf[:n])
			result.error(fmt.Sprintf("internal panic: %v", r))
		}
	}()
	switch action.Method {
	case initClashMethod:
		params := InitParams{}
		if !decodeActionData(action, result, &params) {
			return
		}
		result.success(handleInitClash(&params))
		return
	case getIsInitMethod:
		result.success(handleGetIsInit())
		return
	case forceGcMethod:
		handleForceGC()
		result.success(true)
		return
	case shutdownMethod:
		result.success(handleShutdown())
		return
	case validateConfigMethod:
		path := ""
		if !decodeActionData(action, result, &path) {
			return
		}
		result.success(handleValidateConfig(path))
		return
	case updateConfigMethod:
		params := UpdateParams{}
		if !decodeActionData(action, result, &params) {
			return
		}
		result.success(handleUpdateConfig(&params))
		return
	case setupConfigMethod:
		params := defaultSetupParams()
		if !decodeActionData(action, result, params) {
			return
		}
		result.success(handleSetupConfig(params))
		return
	case getProxiesMethod:
		result.success(handleGetProxies())
		return
	case changeProxyMethod:
		params := ChangeProxyParams{}
		if !decodeActionData(action, result, &params) {
			return
		}
		handleChangeProxy(&params, func(value string) {
			result.success(value)
		})
		return
	case getTrafficMethod:
		onlyStatisticsProxy := false
		if !decodeActionData(action, result, &onlyStatisticsProxy) {
			return
		}
		result.success(handleGetTraffic(onlyStatisticsProxy))
		return
	case getTotalTrafficMethod:
		onlyStatisticsProxy := false
		if !decodeActionData(action, result, &onlyStatisticsProxy) {
			return
		}
		result.success(handleGetTotalTraffic(onlyStatisticsProxy))
		return
	case resetTrafficMethod:
		handleResetTraffic()
		result.success(true)
		return
	case asyncTestDelayMethod:
		params := TestDelayParams{}
		if !decodeActionData(action, result, &params) {
			return
		}
		handleAsyncTestDelay(&params, func(value string) {
			result.success(value)
		})
		return
	case getConnectionsMethod:
		result.success(handleGetConnections())
		return
	case closeConnectionsMethod:
		result.success(handleCloseConnections())
		return
	case resetConnectionsMethod:
		result.success(handleResetConnections())
		return
	case getConfigMethod:
		path := ""
		if !decodeActionData(action, result, &path) {
			return
		}
		config, err := handleGetConfig(path)
		if err != nil {
			result.error(err)
			return
		}
		result.success(config)
		return
	case closeConnectionMethod:
		id := ""
		if !decodeActionData(action, result, &id) {
			return
		}
		result.success(handleCloseConnection(id))
		return
	case getExternalProvidersMethod:
		result.success(handleGetExternalProviders())
		return
	case getExternalProviderMethod:
		externalProviderName := ""
		if !decodeActionData(action, result, &externalProviderName) {
			return
		}
		result.success(handleGetExternalProvider(externalProviderName))
		return
	case updateGeoDataMethod:
		geoType := ""
		if !decodeActionData(action, result, &geoType) {
			return
		}
		handleUpdateGeoData(geoType)
		result.success("")
		return
	case updateExternalProviderMethod:
		providerName := ""
		if !decodeActionData(action, result, &providerName) {
			return
		}
		handleUpdateExternalProvider(providerName, func(value string) {
			result.success(value)
		})
		return
	case sideLoadExternalProviderMethod:
		params := map[string]string{}
		if !decodeActionData(action, result, &params) {
			return
		}
		providerName := params["providerName"]
		data := params["data"]
		handleSideLoadExternalProvider(providerName, []byte(data), func(value string) {
			result.success(value)
		})
		return
	case startLogMethod:
		handleStartLog()
		result.success(true)
		return
	case stopLogMethod:
		handleStopLog()
		result.success(true)
		return
	case startListenerMethod:
		result.success(handleStartListener())
		return
	case stopListenerMethod:
		result.success(handleStopListener())
		return
	case getCountryCodeMethod:
		ip := ""
		if !decodeActionData(action, result, &ip) {
			return
		}
		handleGetCountryCode(ip, func(value string) {
			result.success(value)
		})
		return
	case getMemoryMethod:
		handleGetMemory(func(value string) {
			result.success(value)
		})
		return
	case crashMethod:
		result.success(true)
		handleCrash()
	case deleteFile:
		path := ""
		if !decodeActionData(action, result, &path) {
			return
		}
		handleDelFile(path, result)
		return
	default:
		if !nextHandle(action, result) {
			result.error(fmt.Sprintf("unknown method: %s", action.Method))
		}
	}
}
