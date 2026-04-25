#include "ContentInstaller.h"
#include "Window.h"
#include "components/AsyncNotificationComponent.h"
#include "utils/StringUtil.h"
#include "ApiSystem.h"
#include "LocaleES.h"

#define ICONINDEX _U("\uF019 ")

ContentInstaller*						ContentInstaller::mInstance = nullptr;
std::mutex								ContentInstaller::mLock;
std::list<ContentInstaller::ContentTask>	ContentInstaller::mQueue;
std::list<ContentInstaller::ContentTask>	ContentInstaller::mProcessingQueue;
std::list<IContentInstalledNotify*>		ContentInstaller::mNotification;

void ContentInstaller::Enqueue(Window* window, ContentType type, const std::string contentName)
{
	Enqueue(window, type, ContentTask(type, contentName, contentName));
}

void ContentInstaller::Enqueue(Window* window, ContentType type, const PacmanPackage& package)
{
	Enqueue(window, type, ContentTask(type, package.getQueueKey(), package.name, package));
}

static bool contentTaskMatches(const ContentInstaller::ContentTask& item, ContentInstaller::ContentType type, const std::string& key)
{
	return item.type == type && item.key == key;
}

void ContentInstaller::Enqueue(Window* window, ContentType type, const ContentTask& task)
{
	std::unique_lock<std::mutex> lock(mLock);

	for (auto item : mProcessingQueue)
		if (contentTaskMatches(item, type, task.key))
			return;

	for (auto item : mQueue)
		if (contentTaskMatches(item, type, task.key))
			return;

	mQueue.push_back(task);

	if (mInstance == nullptr)
		mInstance = new ContentInstaller(window);

	mInstance->updateNotificationComponentTitle(true);
}

bool ContentInstaller::IsInQueue(ContentType type, const std::string contentName)
{
	std::unique_lock<std::mutex> lock(mLock);

	for (auto item : mProcessingQueue)
		if (contentTaskMatches(item, type, contentName))
			return true;

	for (auto item : mQueue)
		if (contentTaskMatches(item, type, contentName))
			return true;

	return false;
}

bool ContentInstaller::IsInQueue(ContentType type, const PacmanPackage& package)
{
	return IsInQueue(type, package.getQueueKey());
}

ContentInstaller::ContentInstaller(Window* window)
{
	mInstance = this;

	mCurrent = 0;
	mQueueSize = 0;

	mWindow = window;

	mWndNotification = mWindow->createAsyncNotificationComponent();
	mHandle = new std::thread(&ContentInstaller::threadUpdate, this);
}

ContentInstaller::~ContentInstaller()
{
	mHandle = nullptr;

	mWndNotification->close();
	mWndNotification = nullptr;
}

void ContentInstaller::updateNotificationComponentTitle(bool incQueueSize)
{
	if (incQueueSize)
		mQueueSize++;

	std::string cnt = " " + std::to_string(mCurrent) + "/" + std::to_string(mQueueSize);
	mWndNotification->updateTitle(ICONINDEX + _("DOWNLOADING")+ cnt);
}

void ContentInstaller::updateNotificationComponentContent(const std::string info)
{
	auto pos = info.find(">>>");
	if (pos != std::string::npos)
	{
		std::string percent(info.substr(pos));
		percent = Utils::String::replace(percent, ">", "");
		percent = Utils::String::replace(percent, "%", "");
		percent = Utils::String::replace(percent, " ", "");

		int value = atoi(percent.c_str());

		std::string text(info.substr(0, pos));
		text = Utils::String::trim(text);

		mWndNotification->updatePercent(value);
		mWndNotification->updateText(text);
	}
	else
	{
		mWndNotification->updatePercent(-1);
		mWndNotification->updateText(info);
	}
}

void ContentInstaller::threadUpdate()
{
	mCurrent = 0;

	// Wait for an event to say there is something in the queue
	std::unique_lock<std::mutex> lock(mLock);

	while (true)
	{
		if (mQueue.empty())
			break;

		mCurrent++;
		updateNotificationComponentTitle(false);

		auto data = mQueue.front();
		mQueue.pop_front();
		mProcessingQueue.push_back(data);

		lock.unlock();

		std::pair<std::string, int> updateStatus;
		bool success = false;

		if (data.type == ContentType::CONTENT_THEME_INSTALL)
		{
			updateStatus = ApiSystem::getInstance()->installBatoceraTheme(data.name, [this](const std::string info)
			{
				updateNotificationComponentContent(info);
			});

			if (updateStatus.second == 0)
			{
				success = true;
				mWindow->displayNotificationMessage(ICONINDEX + data.name + " : " + _("THEME INSTALLED SUCCESSFULLY"));
			}
			else
			{
				std::string error = _("AN ERROR OCCURRED") + std::string(": ") + updateStatus.first;
				mWindow->displayNotificationMessage(ICONINDEX + error);
			}

		}
		else if (data.type == ContentType::CONTENT_THEME_UNINSTALL)
		{
			updateStatus = ApiSystem::getInstance()->uninstallBatoceraTheme(data.name, [this](const std::string info)
			{
				updateNotificationComponentContent(info);
			});

			if (updateStatus.second == 0)
			{
				success = true;
				mWindow->displayNotificationMessage(ICONINDEX + data.name + " : " + _("THEME UNINSTALLED SUCCESSFULLY"));
			}
			else
			{
				std::string error = _("AN ERROR OCCURRED") + std::string(": ") + updateStatus.first;
				mWindow->displayNotificationMessage(ICONINDEX + error);
			}

		}
		else if (data.type == ContentType::CONTENT_BEZEL_INSTALL)
		{
			updateStatus = ApiSystem::getInstance()->installBatoceraBezel(data.name, [this](const std::string info)
			{
				updateNotificationComponentContent(info);
			});

			if (updateStatus.second == 0)
			{
				success = true;
				mWindow->displayNotificationMessage(ICONINDEX + data.name + " : " + _("BEZELS INSTALLED SUCCESSFULLY"));
			}
			else
			{
				std::string error = _("AN ERROR OCCURRED") + std::string(": ") + updateStatus.first;
				mWindow->displayNotificationMessage(ICONINDEX + error);
			}
		}
		else if (data.type == ContentType::CONTENT_BEZEL_UNINSTALL)
		{
			updateStatus = ApiSystem::getInstance()->uninstallBatoceraBezel(data.name, [this](const std::string info)
			{
				updateNotificationComponentContent(info);
			});

			if (updateStatus.second == 0)
			{
				success = true;
				mWindow->displayNotificationMessage(ICONINDEX + data.name + " : " + _("BEZELS UNINSTALLED SUCCESSFULLY"));
			}
			else
			{
				std::string error = _("AN ERROR OCCURRED") + std::string(": ") + updateStatus.first;
				mWindow->displayNotificationMessage(ICONINDEX + error);
			}
		}
		else if (data.type == ContentType::CONTENT_STORE_INSTALL)
		{
			if (data.package.isCustomFeed())
				updateStatus = ApiSystem::getInstance()->installCustomContentPackage(data.package, [this](const std::string info)
				{
					updateNotificationComponentContent(info);
				});
			else
				updateStatus = ApiSystem::getInstance()->installBatoceraStorePackage(data.name, [this](const std::string info)
				{
					updateNotificationComponentContent(info);
				});

			if (updateStatus.second == 0)
			{
				success = true;
				mWindow->displayNotificationMessage(ICONINDEX + data.name + " : " + _("PACKAGE INSTALLED SUCCESSFULLY"));
			}
			else
			{
				std::string error = _("AN ERROR OCCURRED") + std::string(": ") + updateStatus.first;
				mWindow->displayNotificationMessage(ICONINDEX + error);
			}
		}
		else if (data.type == ContentType::CONTENT_STORE_UNINSTALL)
		{
			if (data.package.isCustomFeed())
				updateStatus = ApiSystem::getInstance()->uninstallCustomContentPackage(data.package, [this](const std::string info)
				{
					updateNotificationComponentContent(info);
				});
			else
				updateStatus = ApiSystem::getInstance()->uninstallBatoceraStorePackage(data.name, [this](const std::string info)
			{
				updateNotificationComponentContent(info);
			});

			if (updateStatus.second == 0)
			{
				success = true;
				mWindow->displayNotificationMessage(ICONINDEX + data.name + " : " + _("PACKAGE REMOVED SUCCESSFULLY"));
			}
			else
			{
				std::string error = _("AN ERROR OCCURRED") + std::string(": ") + updateStatus.first;
				mWindow->displayNotificationMessage(ICONINDEX + error);
			}
		}

		OnContentInstalled(data.type, data.name, success);

		lock.lock();
		for (auto it = mProcessingQueue.begin(); it != mProcessingQueue.end(); ++it)
		{
			if (it->type == data.type && it->key == data.key)
			{
				mProcessingQueue.erase(it);
				break;
			}
		}
	}

	delete this;
	mInstance = nullptr;
}

void ContentInstaller::OnContentInstalled(int contentType, std::string contentName, bool success)
{
	std::unique_lock<std::mutex> lock(mLock);

	for (IContentInstalledNotify* n : mNotification)
		n->OnContentInstalled(contentType, contentName, success);
}

void ContentInstaller::RegisterNotify(IContentInstalledNotify* instance)
{
	std::unique_lock<std::mutex> lock(mLock);
	mNotification.push_back(instance);
}

void ContentInstaller::UnregisterNotify(IContentInstalledNotify* instance)
{
	std::unique_lock<std::mutex> lock(mLock);

	for (auto it = mNotification.cbegin(); it != mNotification.cend(); it++)
	{
		if ((*it) == instance)
		{
			mNotification.erase(it);
			return;
		}
	}
}
